GOCC=go
USERNAME=hbouvier
PROJECTNAME=http-echo-server
VERSION=$(shell cat VERSION.txt)

all: coverage build release docker

run:
	go run server.go

clean:
	rm -rf coverage.out \
	       ${GOPATH}/pkg/{linux_amd64,darwin_amd64,linux_arm}/github.com/${USERNAME}/${PROJECTNAME} \
	       ${GOPATH}/bin/{linux_amd64,darwin_amd64,linux_arm}/${PROJECTNAME} \
	       release

build: fmt test
	${GOCC} install github.com/${USERNAME}/${PROJECTNAME}

fmt:
	${GOCC} fmt github.com/${USERNAME}/${PROJECTNAME}

test:
	${GOCC} test -v -cpu 4 -count 1 -coverprofile=coverage.out github.com/${USERNAME}/${PROJECTNAME}

coverage: test
	${GOCC} tool cover -html=coverage.out

linux:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 ${GOCC} install github.com/${USERNAME}/${PROJECTNAME}
	@if [[ $(shell uname | tr '[:upper:]' '[:lower:]') == $@ ]] ; then mkdir -p ${GOPATH}/bin/$@_amd64 && mv ${GOPATH}/bin/${PROJECTNAME} ${GOPATH}/bin/$@_amd64/ ; fi

darwin:
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 ${GOCC} install github.com/${USERNAME}/${PROJECTNAME}
	@if [[ $(shell uname | tr '[:upper:]' '[:lower:]') == $@ ]] ; then mkdir -p ${GOPATH}/bin/$@_amd64 && mv ${GOPATH}/bin/${PROJECTNAME} ${GOPATH}/bin/$@_amd64/ ; fi

arm:
	GOOS=linux GOARCH=arm CGO_ENABLED=0 ${GOCC} install github.com/${USERNAME}/${PROJECTNAME}
	@if [[ $(shell uname | tr '[:upper:]' '[:lower:]') == $@ ]] ; then mkdir -p ${GOPATH}/bin/$@_amd64 && mv ${GOPATH}/bin/${PROJECTNAME} ${GOPATH}/bin/$@_amd64/ ; fi

windows:
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 ${GOCC} install github.com/${USERNAME}/${PROJECTNAME}
	@if [[ $(shell uname | tr '[:upper:]' '[:lower:]') == $@ ]] ; then mkdir -p ${GOPATH}/bin/$@_amd64 && mv ${GOPATH}/bin/${PROJECTNAME}.exe ${GOPATH}/bin/$@_amd64/ ; fi

release: linux darwin arm
	@mkdir -p release/bin/{linux_amd64,darwin_amd64,linux_arm}
	for i in linux_amd64 darwin_amd64 linux_arm; do cp ${GOPATH}/bin/$${i}/${PROJECTNAME} release/bin/$${i}/ ; done
	cd release && COPYFILE_DISABLE=1 tar cvzf ${PROJECTNAME}.${VERSION}.tgz bin
	cd release && zip -r ${PROJECTNAME}.${VERSION}.zip bin




docker: docker-build docker-run sleep test

docker-build:
	docker build -t hbouvier/http-echo-server:${VERSION} .

docker-run:
	-docker rm -f http-echo-server
	docker run -d -p 3000:3000 --name http-echo-server hbouvier/http-echo-server:${VERSION}

sleep:
	sleep 5

curl:
	curl -XPOST -sHAccept:application/json -HContent-Type:application/json -H 'X-Curl-Header: was-here' http://localhost:3000/echo -d '{"name":"bob"}' | jq .
	curl -XPOST -sH 'Accept:application/xml' -HContent-Type:application/json -H 'X-Curl-Header: was-here' http://localhost:3000/echo -d '{"name":"bob"}'
	curl -XPOST -sH 'Accept:application/xhtml+xml' -H 'Accept:application/xml' -HContent-Type:application/json -H 'X-Curl-Header: was-here' http://localhost:3000/echo -d '{"name":"bob"}'
	open http://localhost:3000/

docker-push:
	docker push hbouvier/http-echo-server:${VERSION}