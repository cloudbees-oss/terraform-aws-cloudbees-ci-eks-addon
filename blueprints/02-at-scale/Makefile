ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
export ROOT := $(notdir $(patsubst %/,%,$(ROOT_DIR)))
include ../Makefile
