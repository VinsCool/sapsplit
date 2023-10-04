CC = gcc
#CC = clang
#CFLAGS  = -ox -ob -ol+ -onatx -oh -zp8 -fp6 -g0 -Ot -oe -ot -Wall -xc -s -finline-functions -finline-intrinsics -finline-math -floop-optimize -frerun-optimizer -fno-stack-check -march=i386 -mtune=i686
#CFLAGS = -fsanitize=undefined
RM = del
#EXTENSION = .exe

#all: zx2 dzx2 sapsplit

#zx2: zx2.c optimize.c compress.c memory.c zx2.h
#	$(CC) $(CFLAGS) -o ./build/zx2$(EXTENSION) zx2.c optimize.c compress.c memory.c

#dzx2: dzx2.c
#	$(CC) $(CFLAGS) -o ./build/dzx2$(EXTENSION) dzx2.c

#sapsplit: sapsplit.c sapsplit.h optimize.c compress.c memory.c zx2.h
#	$(CC) $(CFLAGS) -o ./build/sapsplit$(EXTENSION) sapsplit.c optimize.c compress.c memory.c

#all: zx02 dzx02 sapsplit

#zx02: zx02.c optimize.c compress.c memory.c zx02.h
#	$(CC) $(CFLAGS) -o ./build/zx02$(EXTENSION) zx02.c optimize.c compress.c memory.c

#dzx02: dzx02.c
#	$(CC) $(CFLAGS) -o ./build/dzx02$(EXTENSION) dzx02.c

all: sapsplit
	
sapsplit: sapsplit.c sapsplit.h ./ZX02/optimize.c ./ZX02/compress.c ./ZX02/memory.c ./ZX02/zx02.h
	$(CC) $(CFLAGS) -o ./build/sapsplit$(EXTENSION) sapsplit.c ./ZX02/optimize.c ./ZX02/compress.c ./ZX02/memory.c

clean:
	$(RM) *.obj
