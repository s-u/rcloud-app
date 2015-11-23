WD=$(shell pwd)
BASE=/Applications/RCloud.app
ROOT=$(BASE)/Contents/Resources/rcloud

all: SessionKeyServer SOLR redis

SessionKeyServer: $(ROOT)/services/SessionKeyServer/SessionKeyServer.jar
SOLR: $(ROOT)/services/solr/example/start.jar
redis: $(ROOT)/services/redis

$(ROOT)/services/SessionKeyServer/SessionKeyServer.java: $(ROOT)
	@echo === checking out Session Key Server
	(cd '$(ROOT)/services' && git clone git@github.com:s-u/SessionKeyServer.git)

$(ROOT)/services/SessionKeyServer/SessionKeyServer.jar: $(ROOT)/services/SessionKeyServer/SessionKeyServer.java
	@echo === building Session Key Server
	(cd '$(ROOT)/services/SessionKeyServer' && make && make pam)

$(ROOT)/services/solr/example/start.jar: $(ROOT)
	@if [ ! -e '$(ROOT)/services/solr/example/start.jar' ]; then echo === installing SOLR; (cd '$(ROOT)/conf/solr' && sh solrsetup.sh '$(ROOT)/services'); fi

$(ROOT)/services/redis: $(ROOT)
	mkdir -p '$@-build'
	(cd '$@-build' && curl -O http://download.redis.io/releases/redis-3.0.5.tar.gz && tar fxz redis-3.0.5.tar.gz && cd redis-3.0.5 && make -j8 && mkdir -p '$@' && mkdir -p '$(ROOT)/../bin' && cp -p src/redis-server '$(ROOT)/../bin/redis-server' && rm -rf '$@-build')

build/Release/RCloud.app:
	@echo === build RCloud app
	xcodebuild

$(BASE): build/Release/RCloud.app
	@echo === copy RCloud.app to $(BASE)
	rsync -a build/Release/RCloud.app/ '$(BASE)/'

$(ROOT): $(BASE)
	@echo === clone RCloud sources
	git clone git@github.com:att/rcloud.git '$(ROOT)'

