
.PHONY: all

all: build/ascsaver

build/ascsaver: ascsaver/ascsaver
	mkdir -p build
	cp ascsaver/ascsaver build/ascsaver

