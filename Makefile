WD=$(shell pwd)
BASE=/Applications/RCloud.app
ROOT=$(BASE)/Contents/Resources/rcloud

all: SessionKeyServer SOLR redis info
	mkdir -p $(ROOT)/data/gists
	mkdir -p $(ROOT)/../Applications
	@if [ ! -e $(ROOT)/conf/rcloud.conf ]; then cp $(WD)/rcloud.conf $(ROOT)/conf/; fi

SessionKeyServer: $(ROOT)/services/SessionKeyServer/SessionKeyServer.jar
SOLR: $(ROOT)/services/solr/example/run
redis: $(ROOT)/services/redis
info:
	@echo ''
	@echo '=== Final steps:'
	@echo ' copy Chrominum.app to $(BASE)/Contents/Resources/Applications'
	@echo ' ROOT=$(BASE)/Contents/Resources/rcloud R_LIBS=$(BASE)/Contents/Resources/rcloud/Rlib sh scripts/bootstrapR.sh '
	@echo ' create $(BASE)/Contents/Resources/rcloud/conf/rcloud.conf'
	@echo ''

$(ROOT)/services/SessionKeyServer/SessionKeyServer.java: $(ROOT)
	@echo === checking out Session Key Server
	(cd '$(ROOT)/services' && git clone git@github.com:s-u/SessionKeyServer.git)

$(ROOT)/services/SessionKeyServer/SessionKeyServer.jar: $(ROOT)/services/SessionKeyServer/SessionKeyServer.java
	@echo === building Session Key Server
	(cd '$(ROOT)/services/SessionKeyServer' && make JFLAGS='-source 1.6 -target 1.6' && make JFLAGS='-source 1.6 -target 1.6' pam)


$(ROOT)/services/solr/example/start.jar: $(ROOT)
	@if [ ! -e '$(ROOT)/services/solr/example/start.jar' ]; then echo === installing SOLR; (cd '$(ROOT)/conf/solr' && sh solrsetup.sh '$(ROOT)/services'); fi


$(ROOT)/services/solr/example/run: $(ROOT)/services/solr/example/start.jar
	echo '#!/bin/sh' > "$@"
	echo '' >> "$@"
	echo 'java -jar start.jar >> solr.log' >> "$@"
	chmod a+rx "$@"

$(ROOT)/services/redis: $(ROOT)
	mkdir -p '$@-build'
	(cd '$@-build' && curl -O http://download.redis.io/releases/redis-3.0.5.tar.gz && tar fxz redis-3.0.5.tar.gz && cd redis-3.0.5 && make -j8 && mkdir -p '$@' && mkdir -p '$(ROOT)/../bin' && cp -p src/redis-server '$(ROOT)/../bin/redis-server' && rm -rf '$@-build')

#$(ROOT)/../Applications/Chromium.app:

build/Release/RCloud.app:
	@echo === build RCloud app
	xcodebuild

$(BASE): build/Release/RCloud.app
	@echo === copy RCloud.app to $(BASE)
	rsync -a build/Release/RCloud.app/ '$(BASE)/'

$(ROOT): $(BASE)
	@echo === clone RCloud sources
	git clone git@github.com:att/rcloud.git '$(ROOT)'

