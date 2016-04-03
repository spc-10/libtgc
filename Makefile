LUA_DIR = $(HOME)/lib/lua

LUAS = src/init.lua src/result.lua src/evaluation.lua src/report.lua src/student.lua

build clean:

install:
	mkdir -p $(LUA_DIR)/tgc
	cp $(LUAS) $(LUA_DIR)/tgc
