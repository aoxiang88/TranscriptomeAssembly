### add two folders to include: CPLEX and CONCERT
CPLEX := ./CPLEX
CONCERT := ./CPLEX-CONCERT
### link architecture
LCPLEX := ./CPLEX/static_pic
LCONCERT := ./CPLEX-CONCERT/static_pic

BAM := ./samtools-0.1.18
#path to the directory where the samtools package was built (in place)
#so libbam.a and *.h files MUST be in here

GDIR :=./gclib

### include two folders
INCDIRS := -I. -I${GDIR} -I${BAM} -I${CPLEX} -I${CONCERT}

#CC := clang++
CC      := g++


ifneq (,$(findstring nothreads,$(MAKECMDGOALS)))
 NOTHREADS=1
endif

#detect MinGW (Windows environment)
ifneq (,$(findstring mingw,$(shell ${CC} -dumpmachine)))
 WINDOWS=1
endif

LFLAGS = 
# MinGW32 GCC 4.5 link problem fix
#ifdef WINDOWS
ifneq (,$(findstring 4.5.,$(shell g++ -dumpversion)))
 LFLAGS += -static-libstdc++ -static-libgcc
endif
#endif

# Misc. system commands
#ifdef WINDOWS
#RM = del /Q
#else
RM = rm -f
#endif

# File endings
ifdef WINDOWS
EXE = .exe
else
EXE =
endif

### add -DIL_STD to the end of BASEFLAGS
BASEFLAGS  := -Wall -Wextra ${INCDIRS} $(MARCH) -D_FILE_OFFSET_BITS=64 \
-D_LARGEFILE_SOURCE -fno-strict-aliasing -fno-exceptions -fno-rtti -DIL_STD -fexceptions

# C/C++ linker

#LINKER := clang++
LINKER  := g++

### modify LIBS at the first time
LIBS := -lbam -lz -lilocplex -lconcert -lcplex -lm -lpthread


# Non-windows systems need pthread
ifndef WINDOWS
 ifndef NOTHREADS
   LIBS += -lpthread
 endif
endif

ifdef NOTHREADS
  BASEFLAGS += -DNOTHREADS
endif

###----- generic build rule

### modify the value of LDFLAGS when create it (three times) 
#ifneq (,$(findstring release,$(MAKECMDGOALS)))
ifneq (,$(filter %release %static, $(MAKECMDGOALS)))
  # -- release build
  CFLAGS := -O3 -DNDEBUG -g $(BASEFLAGS)
  LDFLAGS := -g -L${LCPLEX} -L${LCONCERT} -L${BAM} ${LFLAGS}
  ifneq (,$(findstring static,$(MAKECMDGOALS)))
    LDFLAGS += -static-libstdc++ -static-libgcc
  endif
else
  ifneq (,$(filter %memcheck %memdebug, $(MAKECMDGOALS)))
     #make memcheck : use the statically linked address sanitizer in gcc 4.9.x
     GCCVER49 := $(shell expr `g++ -dumpversion | cut -f1,2 -d.` \>= 4.9)
     ifeq "$(GCCVER49)" "0"
       $(error gcc version 4.9 or greater is required for this build target)
     endif
     CFLAGS := -fno-omit-frame-pointer -fsanitize=undefined -fsanitize=address $(BASEFLAGS)
     GCCVER5 := $(shell expr `g++ -dumpversion | cut -f1 -d.` \>= 5)
     ifeq "$(GCCVER5)" "1"
       CFLAGS += -fsanitize=bounds -fsanitize=float-divide-by-zero -fsanitize=vptr
       CFLAGS += -fsanitize=float-cast-overflow -fsanitize=object-size
       #CFLAGS += -fcheck-pointer-bounds -mmpx
     endif
     CFLAGS := -g -DDEBUG -D_DEBUG -DGDEBUG -fno-common -fstack-protector $(CFLAGS)
     LDFLAGS := -g -L${LCPLEX} -L${LCONCERT} -L${BAM} 
     #LIBS := -Wl,-Bstatic -lasan -lubsan -Wl,-Bdynamic -ldl $(LIBS)
     LIBS := -lasan -lubsan -ldl $(LIBS)
  else
   ifneq (,$(filter %memtrace %memusage %memuse, $(MAKECMDGOALS)))
       BASEFLAGS += -DGMEMTRACE
       GMEMTRACE=1
   endif
   #just plain debug build
    CFLAGS := -g -DDEBUG -D_DEBUG -DGDEBUG $(BASEFLAGS)
    LDFLAGS := -g -L${LCPLEX} -L${LCONCERT} -L${BAM}
  endif
endif

%.o : %.cpp
	${CC} ${CFLAGS} -c $< -o $@

OBJS := ${GDIR}/GBase.o ${GDIR}/GArgs.o ${GDIR}/GStr.o ${GDIR}/GBam.o \
 ${GDIR}/gdna.o ${GDIR}/codons.o ${GDIR}/GFaSeqGet.o ${GDIR}/gff.o 

ifdef GMEMTRACE
 OBJS += ${GDIR}/proc_mem.o
endif

ifndef NOTHREADS
 OBJS += ${GDIR}/GThreads.o 
endif



OBJS += rlink.o tablemaker.o tmerge.o
 
all release static debug: isoref
memcheck memdebug: isoref
memuse memusage memtrace: isoref
nothreads: isoref

${GDIR}/GBam.o : $(GDIR)/GBam.h
isoref.o : $(GDIR)/GBitVec.h $(GDIR)/GHash.hh $(GDIR)/GBam.h
rlink.o : rlink.h tablemaker.h $(GDIR)/GBam.h $(GDIR)/GBitVec.h
tmerge.o : rlink.h tmerge.h
tablemaker.o : tablemaker.h rlink.h
${BAM}/libbam.a: 
	cd ${BAM} && make lib
isoref: ${BAM}/libbam.a $(OBJS) isoref.o
	${LINKER} ${LDFLAGS} -o $@ ${filter-out %.a %.so, $^} ${LIBS}

.PHONY : clean cleanall cleanAll allclean

# target for removing all object files

clean:
	@${RM} isoref isoref.o* isoref.exe $(OBJS)
	@${RM} core.*
allclean cleanAll cleanall:
	cd ${BAM} && make clean
	@${RM} isoref isoref.o* isoref.exe $(OBJS)
	@${RM} core.*


