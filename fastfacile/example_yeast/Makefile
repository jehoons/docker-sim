####################################################################################
# Author: Je-Hoon Song 
# Email: song.jehoon@mgail.com
# Last Update: 2014-10-13 
# 
# This makefile automatically generates _mex.mexa64 and _mex_mat.mexa64 files 
# that runs much faster than matlab ode solvers. The C code uses sundials and 
# openmp libraries to increase its execution performance. 
#
MODEL=g4n
MEX=/usr/local/MATLAB/R2013a/bin/mex
SUNDIALS_DIR=/usr/local/sundials-2.3.0
GSL_DIR=/usr/local/gsl-2.2
USR_DIR=/home/pbs/usr
INC_DIR=-I$(GSL_DIR)/include -I$(SUNDIALS_DIR)/include -I$(USR_DIR)/include
LIB_DIR=-L$(GSL_DIR)/lib -L$(SUNDIALS_DIR)/lib -L$(USR_DIR)/lib
LIBS=-lsundials_cvodes -lsundials_cvode -lsundials_nvecserial -lgomp -lgsl -lgslcblas -lm
MODELDEF=$(MODEL).eqn

all: ranges.m $(MODEL)_cv.c $(MODEL)_cv.h $(MODEL).maple $(MODEL)_odes.m \
	$(MODEL)_rates.m $(MODEL)_ivalues.m $(MODEL)_mex.c $(MODEL)_mex_mat.c \
	$(MODEL).mexa64 $(MODEL)_c.mexa64 $(MODEL)_L.mexa64 $(MODEL)_LSS.mexa64 \
	$(MODEL).so $(MODEL)_L.so

# $(MODEL)_mex.mexa64 $(MODEL)_mex_mat.mexa64
# $(MODEL).so

$(MODEL).maple: $(MODELDEF)
	facile.pl -L $(MODELDEF)

$(MODEL)_odes.m: $(MODELDEF)
	facile.pl -m $(MODELDEF)

ranges.m: $(MODELDEF)
	genRange.py $(MODELDEF)

$(MODEL)_ivalues.m $(MODEL)_rates.m: $(MODELDEF)
	genDefaultPar.py $(MODELDEF)

$(MODEL)_mex.c $(MODEL)_mex_mat.c: 
	genMexfile.py $(MODEL)

$(MODEL).vf: $(MODEL).maple
	factools.py $(MODEL).maple > $(MODEL).vf

$(MODEL)_cv.c $(MODEL)_cv.h: $(MODEL).vf
	vfgen cvode:version=2.5.0 $(MODEL).vf 

# note 1) the -f option should be followed by source names. otherwise,
# mexopts.sh does not have any effect. 
# note 2) to feed EXTRA_FLAG, give argument EXTRA_FLAG="-DWITH_OMP" to 
# Makefile. For example, make EXTRA_FLAG="-DWITH_OMP" <enter>
EXTRA_FLAG=-DWITH_OMP 

$(MODEL)_c.mexa64: $(MODEL)_mex.c
	$(MEX) -DMATLAB $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) $(LIBS) $(MODEL)_mex.c -output $@ \
		-f ./mexopts_omp.sh 

$(MODEL).mexa64: $(MODEL)_mex_mat.c
	$(MEX) -DMATLAB $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) $(LIBS) $(MODEL)_mex_mat.c -output $@ \
		-f ./mexopts_omp.sh

$(MODEL)_L.mexa64: $(MODEL)_mex_mat.c
	$(MEX) -DMATLAB -DLANGEVIN $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) $(LIBS) $(MODEL)_mex_mat.c -output $@ \
		-f ./mexopts_omp.sh

$(MODEL)_LSS.mexa64: $(MODEL)_mex_mat.c
	$(MEX) -DMATLAB -DLANGEVIN -DSTEADY $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) $(LIBS) $(MODEL)_mex_mat.c -output $@ \
		-f ./mexopts_omp.sh 

$(MODEL)_mex_mat.o: $(MODEL)_mex_mat.c
	gcc $(EXTRA_FLAG) $(INC_DIR) -fopenmp -fPIC -g -c -Wall $< -o $@ 

$(MODEL).so: $(MODEL)_mex_mat.o 
	gcc $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) -shared -Wl,-soname,g4n.so -Wl,--no-undefined -o -lc $< -o $@ $(LIBS)

$(MODEL)_mex_mat_L.o: $(MODEL)_mex_mat.c
	gcc -DLANGEVIN $(EXTRA_FLAG) $(INC_DIR) -fopenmp -fPIC -g -c -Wall $< -o $@ 

$(MODEL)_L.so: $(MODEL)_mex_mat_L.o 
	gcc -DLANGEVIN $(EXTRA_FLAG) $(INC_DIR) $(LIB_DIR) -shared -Wl,-soname,g4n.so -Wl,--no-undefined -o -lc $< -o $@ $(LIBS)

clean:
	rm -f *.pyc
	rm -f $(MODEL).so
	rm -f $(MODEL)_L.so
	rm -f $(MODEL)_cv.c 
	rm -f $(MODEL)_cv.h 
	rm -f $(MODEL).vf 
	rm -f $(MODEL).maple 
	rm -f $(MODEL).ma
	rm -f $(MODEL)_odes.py
	rm -f $(MODEL)Driver.m 
	rm -f $(MODEL)Driver.py
	rm -f $(MODEL)_odes.m 
	rm -f $(MODEL)_r.m 
	rm -f $(MODEL)_r.py
	rm -f $(MODEL)_s.m 
	rm -f $(MODEL)_s.py
	rm -f $(MODEL)_ode23.m
	rm -f $(MODEL)_engine.m
	rm -f $(MODEL)_ivalues.m
	rm -f $(MODEL)_rates.m
	rm -f $(MODEL)_mex.c
	rm -f $(MODEL)_mex_mat.c
	rm -f *.mexa64 *.o 
	rm -f ranges.m
	rm -f ode_size.h
	rm -f ratesLabels.m
	rm -f statesLabels.m
	rm -f *~
	rm -f *.jpg
	rm -f *.eps
	rm -rf __pycache__
	
