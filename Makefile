.DEFAULT_GOAL := default

ifndef EXE
	EXE=radiance
endif

ifdef EVALFILE
	evalfile_param = "-Devalfile=$(EVALFILE)"
endif

window_cmd=cmd /C move .\zig-out\bin\radiance.exe $(EXE).exe
linux_cmd=mv zig-out/bin/radiance $(EXE)

# ifdef WSL_DISTRO_NAME
# 	windows_cmd = $(linux_cmd)
# endif

ifeq ($(OS), Windows_NT)
	MV=$(window_cmd)
else
	MV=$(linux_cmd)
endif

print-os:
	$(info OS = $(OS))

default:
	zig build --release=fast $(evalfile_param)
	@echo $(MV)
	@$(MV)
