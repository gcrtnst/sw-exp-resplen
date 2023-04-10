package main

import (
	"bufio"
	"bytes"
	"errors"
	"log"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

func TestServerServeConn(t *testing.T) {
	tt := []struct {
		req      string
		writeErr error
		respLen  int
		log      string
	}{
		{
			req:      makeRequest("/?n=0"),
			writeErr: nil,
			respLen:  17,
			log:      "resp_size=17, body_size=0\n",
		},
		{
			req:      makeRequest("/?n=1"),
			writeErr: nil,
			respLen:  18,
			log:      "resp_size=18, body_size=1\n",
		},
		{
			req:      makeRequest("/?n=255"),
			writeErr: nil,
			respLen:  272,
			log:      "resp_size=272, body_size=255\n",
		},
		{
			req:      makeRequest("/a?n=0"),
			writeErr: nil,
			respLen:  0,
			log:      "error: sw-test-resplen: invalid url path\n",
		},
		{
			req:      makeRequest("/?n=0"),
			writeErr: errors.New("testing write error"),
			respLen:  17,
			log: "resp_size=17, body_size=0\n" +
				"error: testing write error\n",
		},
	}

	for ti, tc := range tt {
		conn := &testConn{
			Reader:   strings.NewReader(tc.req),
			Writer:   new(bytes.Buffer),
			WriteErr: tc.writeErr,
			Closed:   false,
		}

		logbuf := new(strings.Builder)
		logger := log.New(logbuf, "", 0)

		srv := NewServer(1)
		srv.Logger = logger

		srv.ServeConn(conn)

		resp := conn.Writer.Bytes()
		if len(resp) != tc.respLen {
			t.Errorf("case %d: response length: expected %d, got %d", ti, tc.respLen, len(resp))
		}

		logstr := logbuf.String()
		if logstr != tc.log {
			t.Errorf("case %d: log: expected %#v, got %#v", ti, tc.log, logstr)
		}

		if !conn.Closed {
			t.Errorf("case %d: conn not closed", ti)
		}
	}
}

func TestServerMakeResponseFormat(t *testing.T) {
	re := regexp.MustCompile(`\A` + regexp.QuoteMeta("HTTP/1.0 200 \r\n\r\n") + `(?P<body>.*)\z`)

	tt := []int{0, 1, 255}
	for ti, reqN := range tt {
		req := &Request{Proto: "HTTP/1.0", N: reqN}

		srv := NewServer(1)
		resp, err := srv.MakeResponse(req)
		if err != nil {
			t.Errorf("case %d: %v", ti, err)
			continue
		}

		matches := re.FindSubmatch(resp)
		if matches == nil {
			t.Errorf("case %d: invalid response format", ti)
			continue
		}

		respN := len(matches[re.SubexpIndex("body")])
		if respN != reqN {
			t.Errorf("case %d: response body length: expected %d, got %d", ti, reqN, respN)
			continue
		}
	}
}

func TestServerMakeResponseNormal(t *testing.T) {
	tt := []*Request{
		{Proto: "HTTP/1.0", N: 0},
		{Proto: "HTTP/1.1", N: 0},
	}

	for ti, req := range tt {
		srv := NewServer(1)
		resp, err := srv.MakeResponse(req)

		if resp == nil {
			t.Errorf("case %d: resp is nil", ti)
		}
		if err != nil {
			t.Errorf("case %d: %v", ti, err)
		}
	}
}

func TestServerMakeResponseError(t *testing.T) {
	tt := []*Request{
		{Proto: "HTTP/2.0", N: 0},
		{Proto: "HTTP/1.0", N: -1},
	}

	for ti, req := range tt {
		srv := NewServer(1)
		resp, err := srv.MakeResponse(req)

		if resp != nil {
			t.Errorf("case %d: resp is not nil", ti)
		}
		if err == nil {
			t.Errorf("case %d: no error", ti)
		}
	}
}

func TestReadRequestNormal(t *testing.T) {
	tt := []struct {
		raw string
		req *Request
	}{
		{
			raw: makeRequest("/?n=0"),
			req: &Request{
				Proto: "HTTP/1.1",
				N:     0,
			},
		},
		{
			raw: makeRequest("/?n=1"),
			req: &Request{
				Proto: "HTTP/1.1",
				N:     1,
			},
		},
		{
			raw: makeRequest("/?n=255"),
			req: &Request{
				Proto: "HTTP/1.1",
				N:     255,
			},
		},
	}

	for ti, tc := range tt {
		b := bufio.NewReader(strings.NewReader(tc.raw))

		req, err := ReadRequest(b)
		if err != nil {
			t.Errorf("case %d: %v", ti, err)
			continue
		}
		if !reflect.DeepEqual(req, tc.req) {
			t.Errorf("case %d: req: expected %#v, got %#v", ti, tc.req, req)
			continue
		}
	}
}

func TestReadRequestError(t *testing.T) {
	tt := []string{
		makeRequest("invalid"),
		makeRequest("/a?n=0"),
		makeRequest("/?l=0"),
		makeRequest("/?n=a"),
		makeRequest("/?n=-1"),
	}

	for ti, raw := range tt {
		b := bufio.NewReader(strings.NewReader(raw))

		req, err := ReadRequest(b)
		if req != nil {
			t.Errorf("case %d: req is not nil", ti)
			continue
		}
		if err == nil {
			t.Errorf("case %d: no error", ti)
			continue
		}
	}
}

type testConn struct {
	Reader   *strings.Reader
	Writer   *bytes.Buffer
	WriteErr error
	Closed   bool
}

func (c *testConn) Read(p []byte) (int, error) {
	return c.Reader.Read(p)
}

func (c *testConn) Write(p []byte) (int, error) {
	n, _ := c.Writer.Write(p)
	return n, c.WriteErr
}

func (c *testConn) Close() error {
	c.Closed = true
	return nil
}

func makeRequest(target string) string {
	return "GET " + target + " HTTP/1.1\r\n" +
		"Host: 127.0.0.1\r\n" +
		"Accept-Encoding: identity\r\n" +
		"Connection: close\r\n" +
		"Content-type: application/x-www-form-urlencoded\r\n" +
		"Accept: text/plain\r\n" +
		"\r\n"
}
