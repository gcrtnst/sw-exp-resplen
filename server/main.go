package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
)

func main() {
	code := run()
	os.Exit(code)
}

func run() int {
	port := flag.Int("port", 0, "listen port")
	seed := flag.Int64("seed", 1, "seed value")
	flag.Parse()

	addr := &net.TCPAddr{
		IP:   net.IPv4(127, 0, 0, 1),
		Port: *port,
	}
	lis, err := net.ListenTCP("tcp", addr)
	if err != nil {
		log.Printf("error: %v", err)
		return 1
	}
	defer func() {
		err := lis.Close()
		if err != nil {
			panic(err)
		}
	}()
	log.Printf("listening on %s", lis.Addr().String())

	srv := NewServer(*seed)
	err = srv.Accept(lis)
	if err != nil {
		panic(err)
	}

	return 0
}

type Server struct {
	Rand   *SyncRand
	Logger *log.Logger
}

func NewServer(seed int64) *Server {
	return &Server{
		Rand:   NewSyncRand(seed),
		Logger: log.Default(),
	}
}

func (s *Server) Accept(lis net.Listener) error {
	for {
		conn, err := lis.Accept()
		if err != nil {
			return err
		}
		go s.ServeConn(conn)
	}
}

func (s *Server) ServeConn(conn io.ReadWriteCloser) {
	defer func() {
		err := conn.Close()
		if err != nil {
			panic(err)
		}
	}()

	connrd := bufio.NewReader(conn)
	req, err := ReadRequest(connrd)
	if err != nil {
		s.Logger.Printf("error: %v", err)
		return
	}

	resp, err := s.MakeResponse(req)
	if err != nil {
		panic(err)
	}
	s.Logger.Printf("resp_size=%d, body_size=%d", len(resp), req.N)

	_, err = conn.Write(resp)
	if err != nil {
		s.Logger.Printf("error: %v", err)
		return
	}
}

func (s *Server) MakeResponse(req *Request) ([]byte, error) {
	if req.Proto != "HTTP/1.0" && req.Proto != "HTTP/1.1" {
		return nil, errors.New("sw-test-resplen: unsupported protocol")
	}
	if req.N < 0 {
		return nil, errors.New("sw-test-resplen: length less than zero")
	}

	buf := new(bytes.Buffer)
	_, _ = buf.WriteString(req.Proto + " 200 \r\n\r\n")
	_, _ = io.CopyN(buf, s.Rand, req.N)
	return buf.Bytes(), nil
}

func ReadRequest(b *bufio.Reader) (*Request, error) {
	// assuming HTTP/1.x
	httpreq, err := http.ReadRequest(b)
	if err != nil {
		return nil, err
	}

	err = httpreq.Body.Close()
	if err != nil {
		panic(err)
	}

	if httpreq.URL.Path != "/" {
		return nil, errors.New("sw-test-resplen: invalid url path")
	}

	t := httpreq.URL.Query().Get("n")
	if t == "" {
		return nil, errors.New("sw-test-resplen: length not specified")
	}

	n, err := strconv.ParseInt(t, 10, 64)
	if err != nil {
		return nil, err
	}
	if n < 0 {
		return nil, errors.New("sw-test-resplen: length less than zero")
	}

	req := &Request{
		Proto: httpreq.Proto,
		N:     n,
	}
	return req, nil
}

type Request struct {
	Proto string
	N     int64
}

type SyncRand struct {
	mu  sync.Mutex
	rng *rand.Rand
}

func NewSyncRand(seed int64) *SyncRand {
	src := rand.NewSource(seed)
	rng := rand.New(src)
	return &SyncRand{rng: rng}
}

func (r *SyncRand) Read(p []byte) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.rng.Read(p)
}
