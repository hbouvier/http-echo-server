package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
)

type Header struct {
	Key   string
	Value []string
}

type Request struct {
	Path    string              `xml:"path,attr"`
	Headers []Header            `xml:"headers>header"`
	Body    string              `xml:"body"`
	Method  string              `xml:"method"`
	Host    string              `xml:"host"`
	Params  map[string][]string `xml:"params>param"`
	Proto   string              `xml:"proto"`
}

func toHeader(header *http.Header) []Header {
	result := make([]Header, 0)
	for key, value := range *header {
		result = append(result, Header{Key: key, Value: value})
	}
	sort.Slice(result[:], func(i, j int) bool {
		return result[i].Key < result[j].Key
	})

	return result
}

func toParams(query url.Values) map[string][]string {
	params := make(map[string][]string)

	for key, value := range query {
		params[key] = value
	}
	return params
}

func createRequest(req *http.Request) (*Request, error) {
	path := req.URL.Path
	buffer, err := ioutil.ReadAll(req.Body)
	if err != nil {
		return nil, err
	}
	body := string(buffer[:])
	request := &Request{
		Headers: toHeader(&req.Header),
		Body:    body,
		Path:    path,
		Method:  req.Method,
		Host:    req.Host,
		Params:  toParams(req.URL.Query()),
		Proto:   req.Proto}
	return request, nil
}

func toHTML(request Request) ([]byte, error) {
	page := "templates/index.html"
	tmpl, err := template.ParseFiles(page)
	if err != nil {
		return nil, err
	}
	var buffer bytes.Buffer
	if err := tmpl.Execute(&buffer, request); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func stringInSlice(a string, list []string) bool {
	for _, b := range list {
		if b == a {
			return true
		}
	}
	return false
}

func negotiateAcceptedContent(accpectedContent []string, supportedTokens []string) string {
	for _, accept := range accpectedContent {
		if stringInSlice(accept, supportedTokens) {
			return accept
		}
	}
	return "*/*"
}

func requestHandler(res http.ResponseWriter, req *http.Request) {
	var err error
	var response []byte
	var request *Request
	res.Header().Set("Server", "HTTP echo server")
	request, err = createRequest(req)
	if err != nil {
		log.Println(err.Error())
		http.Error(res, err.Error(), http.StatusInternalServerError)
		return
	}

	accpectedContent := req.Header["Accept"]
	if len(accpectedContent) == 1 {
		accpectedContent = strings.Split(accpectedContent[0], ",")
	}

	supportedTokens := []string{"application/json", "text/html", "application/xml", "*/*"}
	accept := negotiateAcceptedContent(accpectedContent, supportedTokens)
	log.Println(
		fmt.Sprintf("%s http://%s%s => Negotiated content type: %s",
			request.Method, request.Host, request.Path, accept))

	switch accept {
	case "application/json", "*/*":
		response, err = json.Marshal(request)
		if err != nil {
			log.Println(err.Error())
			http.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}
		res.Header().Set("Content-Type", "application/json")
	case "application/xml":
		response, err = xml.MarshalIndent(request, "", "  ")
		if err != nil {
			log.Println(err.Error())
			http.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}
		res.Header().Set("Content-Type", "application/xml")
	case "text/html":
		res.Header().Set("Content-Type", "text/html")
		response, err = toHTML(*request)
		if err != nil {
			log.Println(err.Error())
			http.Error(res, err.Error(), http.StatusInternalServerError)
			return
		}
	default:
		message := fmt.Sprintf("Unsupported Accept type: %s", accept)
		err = errors.New(message)
		log.Println(err.Error())
		http.Error(res, err.Error(), http.StatusInternalServerError)
		return
	}
	res.Write(response)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "localhost:3000"
	}
	if strings.Index(port, ":") == -1 {
		port = ":" + port
	}
	fs := http.FileServer(http.Dir("public"))
	http.Handle("/favicon.ico", fs)
	http.Handle("/manifest.json", fs)
	http.Handle("/public/", http.StripPrefix("/public/", fs))
	http.HandleFunc("/", requestHandler)
	//  http.HandleFunc("/echo", echoHandler)
	log.Println("Listening on ", port)
	http.ListenAndServe(port, nil)
}
