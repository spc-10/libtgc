LUA_DIR = $(HOME)/lib/lua
TGC_DIR = $(LUA_DIR)/tgc
SRC_DIR = src/tgc

TGC_LUAS = $(SRC_DIR)/init.lua \
		   $(SRC_DIR)/student.lua \
		   $(SRC_DIR)/eval.lua \
		   $(SRC_DIR)/grade.lua \
		   $(SRC_DIR)/result.lua \
		   $(SRC_DIR)/catrule.lua \
		   $(SRC_DIR)/utils.lua
#		   $(SRC_DIR)/competency.lua \

build clean:

install:
	mkdir -p $(TGC_DIR)
	cp $(TGC_LUAS) $(TGC_DIR)
