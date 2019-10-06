LUA_DIR = $(HOME)/lib/lua

LUAS = src/init.lua src/result.lua src/student.lua src/utils.lua

build clean:

install:
	mkdir -p $(LUA_DIR)/tgc
	mkdir -p $(LUA_DIR)/tgc/result
	mkdir -p $(LUA_DIR)/tgc/student
	mkdir -p $(LUA_DIR)/tgc/utils
	cp src/init.lua $(LUA_DIR)/tgc
	cp src/result.lua $(LUA_DIR)/tgc/result/init.lua
	cp src/student.lua $(LUA_DIR)/tgc/student/init.lua
	cp src/utils.lua $(LUA_DIR)/tgc/utils/init.lua

	#cp $(LUAS) $(LUA_DIR)/tgc
