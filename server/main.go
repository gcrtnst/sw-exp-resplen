package main

import (
	"bufio"
	"errors"
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
)

func main() {
	code := run()
	os.Exit(code)
}

func run() int {
	port := flag.Int("port", 0, "listen port")
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

	srv := NewServer()
	err = srv.Accept(lis)
	if err != nil {
		panic(err)
	}

	return 0
}

type Server struct {
	Logger *log.Logger
}

func NewServer() *Server {
	return &Server{
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

	resp, err := MakeResponse(req)
	if err != nil {
		panic(err)
	}
	s.Logger.Printf("resp_len=%d, body_len=%d", len(resp), req.N)

	_, err = conn.Write(resp)
	if err != nil {
		s.Logger.Printf("error: %v", err)
		return
	}
}

type Request struct {
	Proto string
	N     int
}

const MaxN = 1 << 30 // 1 GiB

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

	n, err := strconv.ParseInt(t, 10, 0)
	if err != nil {
		return nil, err
	}
	if n < 0 || MaxN < n {
		return nil, errors.New("sw-test-resplen: invalid length")
	}

	req := &Request{
		Proto: httpreq.Proto,
		N:     int(n),
	}
	return req, nil
}

func MakeResponse(req *Request) ([]byte, error) {
	if req.Proto != "HTTP/1.0" && req.Proto != "HTTP/1.1" {
		return nil, errors.New("sw-test-resplen: unsupported protocol")
	}
	if req.N < 0 || MaxN < req.N {
		return nil, errors.New("sw-test-resplen: invalid length")
	}

	start := req.Proto + " 200 \r\n\r\n"
	rlen := len(start) + req.N // no overflow due to small MaxN
	resp := make([]byte, rlen)
	copy(resp, []byte(start))
	for i := len(start); i < len(resp); i++ {
		resp[i] = '.'
	}
	return resp, nil
}
