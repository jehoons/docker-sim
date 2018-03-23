/* CMEX simulation engine framework
 * Version 1.1
 * Author: Je-Hoon Song, Email: song.jehoon@gmail.com
 * Last update: 1 Apr, 2015
 * */
#include "mex.h"
#include "math.h"
#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include <sundials/sundials_types.h>
#include <sundials/sundials_dense.h>
#include <sundials/sundials_nvector.h>
#include <nvector/nvector_serial.h>
#include <cvode/cvode.h>
#include <cvode/cvode_dense.h>
#include <omp.h>
#include "ode_size.h"
#include "$(MODEL)_cv.c"

#define PACKAGE_SIZE   (10) 
#define THREAD_NUM     (64)

#define SOLVER_ABS_ERROR    1.0e-8
#define SOLVER_REL_ERROR    1.0e-7
#define MAX_STEPS           1.0e+8
#define MAX_SOLVER_TRY      3

void transpose(mxArray*dest, const mxArray*src);

int worker(double *tvec, int tvec_size, int num_species, int num_parameter, 
        realtype *ivalues, realtype *rates, double* ptr_y_dynamics, 
        double* ptr_y_steady) {
    int i, j;
    int flag;
    int argc = 1;
    char *argv[] = { "default" };
    realtype *y_ = (realtype*) malloc(sizeof(realtype) * num_species);
    realtype *p_ = (realtype*) malloc(sizeof(realtype) * num_parameter);
    char *solver_param_names_[4] = { "abserr", "relerr", "stoptime", "maxsteps" };
    double Tend = tvec[tvec_size - 1];
    realtype solver_param_[4] = { RCONST(SOLVER_ABS_ERROR), RCONST(SOLVER_REL_ERROR), 
        RCONST(Tend), RCONST(MAX_STEPS) };
    int t_idx;

#define Ydynamics(ti,y) ptr_y_dynamics[(ti) + (y)*tvec_size] 
#define Ysteady(ky) ptr_y_steady[ky]
    
    for (i = 0; i < num_species; ++i)
        y_[i] = ivalues[i];
    
    for (i = 0; i < num_parameter; ++i)
        p_[i] = rates[i];
    
    N_Vector y0_;
    y0_ = N_VNew_Serial(num_species);
 
    for (i = 0; i < num_species; ++i)
        NV_Ith_S(y0_, i) = y_[i];
    
    /* For non-stiff problems:   */
    /* void *cvode_mem = CVodeCreate(CV_ADAMS, CV_FUNCTIONAL);*/

    /* For stiff problems:       */
    void *cvode_mem = CVodeCreate(CV_BDF,CV_NEWTON);
    realtype t, t1 ; 
    t_idx = 0; 
    int n_try = 1;

    t = RCONST(0.0);
    flag = CVodeMalloc(cvode_mem, $(MODEL)_vf, t, y0_, CV_SS, solver_param_[1], 
            &(solver_param_[0]));
    flag = CVodeSetFdata(cvode_mem, &(p_[0]));
    flag = CVDense(cvode_mem, num_species);
    flag = CVDenseSetJacFn(cvode_mem, $(MODEL)_jac, &(p_[0]));
    t1 = solver_param_[2];
    flag = CVodeSetStopTime(cvode_mem, t1);
 
    while(t_idx < tvec_size && n_try <= MAX_SOLVER_TRY) {
        t = RCONST(0.0); /* reset start time */
        /*if (n_try>1) mexPrintf("Retry: %d\n", n_try-1);*/
        for (t_idx = 0; t_idx < tvec_size; ++t_idx) {
            double tout = tvec[t_idx];
            if (tout == 0) {
                for (j = 0; j < num_species; ++j)
                    Ydynamics(t_idx, j) = NV_Ith_S(y0_, j); 
            } else {
                /* Advance the solution */
                flag = CVode(cvode_mem, tout, y0_, &t, CV_NORMAL);
                if (flag != CV_SUCCESS && flag != CV_TSTOP_RETURN) {
                    fprintf(stderr, "flag=%d (%dth try)\n", flag, n_try++);
                    break;
                }
                for (j = 0; j < num_species; ++j)
                    Ydynamics(t_idx, j) = NV_Ith_S(y0_, j); 
            } /* if */
        } /* for */
    } /* while */
    
    /* copy the last value from timeseries data */
    for (j = 0; j < num_species; ++j) {
        Ysteady(j) = Ydynamics (tvec_size-1, j);
    }

    /* free sundials memory */
    N_VDestroy_Serial(y0_);
    CVodeFree(&cvode_mem);
    free(y_);
    free(p_);

    return flag; 
}

void mexFunction(int nlhs, mxArray *plhs[], /* Output variables */
        int nrhs, const mxArray *prhs[]) /* Input variables */ {
#define Y plhs[0]
#define yf plhs[1]
#define flag plhs[2]
#define TIME_VECTOR prhs[0]
#define input_ivalues prhs[1]
#define input_rates prhs[2]
    double *pTimeVector;
    double *pInitialConditions; 
    double *pRateConstants; 
    double *pOutput; 
    int SizeTimeVector = 0; 
    int MTimeVector = 0; 
    int MInitialConditions = 0; 
    int NInitialConditions = 0; 
    int MRateConstants = 0; 
    int NRateConstants = 0;    
    int i = 0, j = 0; 
    double *pOutputFlag; 
    double *pOutputFV;
    double *pOutputFV2;
    /* mxArray *yf_; */
    /*mxArray *input_ivalues_; */

    /* initial condition is given as M_samples X N_ivalues 
     * */
    int M_samples = mxGetM(input_ivalues);
    int N_ivalues = mxGetN(input_ivalues);
    /* input_ivalues is transposed to adapt the worker function 
     * */
    mxArray *input_ivalues_ = mxCreateDoubleMatrix(N_ivalues, 
            M_samples, mxREAL); 
    transpose(input_ivalues_, input_ivalues); 

    /* rates is given as M_samples X N_rates 
     * */
    int M_samples2 = mxGetM(input_rates); 
    int N_rates = mxGetN(input_rates); 
    mxArray *input_rates_ = mxCreateDoubleMatrix(N_rates, 
            M_samples2, mxREAL); 
    transpose(input_rates_, input_rates); 

    if(nlhs!=2 && nlhs!=1 && nlhs!=3) {
        mexErrMsgTxt("Wrong number of output arguments.");
    }
    if(nrhs!=3) {
        mexErrMsgTxt("Wrong number of input arguments.");
    }    
    MTimeVector = mxGetM(TIME_VECTOR); 
    SizeTimeVector = mxGetN(TIME_VECTOR); 
    pTimeVector = mxGetPr(TIME_VECTOR); 

    if(MTimeVector!=1) {
        mexErrMsgTxt("MTimeVector should be 1!\n");
    }
    if(SizeTimeVector<3) {
        mexErrMsgTxt("NTimeVector should be at least 3!\n");
    }

    MInitialConditions = mxGetM(input_ivalues_); 
    NInitialConditions = mxGetN(input_ivalues_); /* samples */
    pInitialConditions = mxGetPr(input_ivalues_);     

    MRateConstants = mxGetM(input_rates_);
    NRateConstants = mxGetN(input_rates_); /* samples */
    pRateConstants = mxGetPr(input_rates_);

    if(NRateConstants != NInitialConditions) {
        mexPrintf("Nrates = %d, Nivalues = %d\n", NRateConstants, NInitialConditions);
        mexErrMsgTxt("MRateConstants should be same as the MInitialConditions!\n");
    }

    /* output memory allocation - full timeseries data */
    Y = mxCreateCellMatrix(NInitialConditions,1); 
    
    /* output memory allocation - flag  */
    flag = mxCreateDoubleMatrix(NInitialConditions,1,mxREAL); 
    pOutputFlag = mxGetPr(flag); 

    /* output memory allocation - finalvalue, same dimension as initial value */
    mxArray*yf_ = mxCreateDoubleMatrix(MInitialConditions,NInitialConditions,mxREAL); 
    /*yf = mxCreateDoubleMatrix(NInitialConditions,MInitialConditions,mxREAL); */
    pOutputFV = mxGetPr(yf_); 
    /*pOutputFV2 = mxGetPr(yf);*/

    for (i=0;i<NInitialConditions;i++) {
        mxArray *a_mxArray = mxCreateDoubleMatrix(SizeTimeVector, MInitialConditions, 
                mxREAL); 
        mxSetCell(Y, i, a_mxArray);
    }
    /* check the number of initial conditions 
     * */
    if(MInitialConditions != __N_SPECIES__)
        mexErrMsgTxt("wrong number of initials\n");
    /* check the number of rateconstants 
     * */
    if(MRateConstants != __N_PARAMETERS__)
        mexErrMsgTxt("wrong number of rates\n");

    /*int chunk_size = NRateConstants/THREAD_NUM/PACKAGE_SIZE; */
    int chunk_size = PACKAGE_SIZE; 
    if (chunk_size==0) chunk_size = 1; 
    if (chunk_size==1) omp_set_num_threads(1); 
    else omp_set_num_threads(THREAD_NUM); /* bug??? */

    /*mexPrintf("max_thread: %d\n",omp_get_max_threads());*/

#define P_RATECONSTANTS(k) &pRateConstants[0+(k)*MRateConstants] 
#define P_INITIALCOND(k) &pInitialConditions[0+(k)*MInitialConditions] 
#define P_FV(k) &pOutputFV[0+(k)*MInitialConditions] /* dim_fv == dim_ic */

    if (THREAD_NUM==-1) /* auto detection */
        omp_set_num_threads(omp_get_max_threads()); 
    else
        omp_set_num_threads(THREAD_NUM); /* fix the thread number */

    /* There's too many error output in sundials, 
     * so i decided to close it. */
    FILE * freopenResult;    
    freopenResult = freopen("/dev/null","w",stderr);
#ifdef WITH_OMP
#pragma omp parallel for shared(chunk_size, NRateConstants,pTimeVector,SizeTimeVector, \
        MInitialConditions,MRateConstants,pRateConstants,pInitialConditions,pOutputFV,plhs) private (j,i)
#endif
    for (j=0; j<NRateConstants; j+=chunk_size){
        for(i=j;i<=j+chunk_size-1;++i) {
            if(i>=NRateConstants) continue; 
            /*mexPrintf("i = %d\n", i);*/
            pOutputFlag[i] = (double)worker(pTimeVector, SizeTimeVector, MInitialConditions, MRateConstants, 
                    P_INITIALCOND(i), P_RATECONSTANTS(i), mxGetPr(mxGetCell(Y,i)), 
                    P_FV(i));
        }
    }
    freopenResult = freopen("/dev/tty","w",stderr);

    /*transpose*/
    yf = mxCreateDoubleMatrix(NInitialConditions,MInitialConditions,mxREAL);
    transpose(yf, yf_); 
    /*destroy array*/
    mxDestroyArray(yf_); 
    mxDestroyArray(input_ivalues_); 
    mxDestroyArray(input_rates_); 
    return ;
}

void transpose(mxArray*dest, const mxArray*src) {
    int ii, jj; 
    int numRows=(int)mxGetM(src);
    int numCols=(int)mxGetN(src);
#ifdef WITH_OMP
#pragma omp parallel for shared(numCols, numRows, dest, src) private (jj,ii)
#endif
    for(jj=0; jj<numCols; jj++) {
        for(ii=0; ii<numRows; ii++) {
            mxGetPr(dest)[numCols*ii+jj] = mxGetPr(src)[numRows*jj+ii];
        }
    }
}

/* use following command to compile in matlab: 
%build model: 
mex -I/home/jhsong/usr/include -L/home/jhsong/usr/lib ...
    -lsundials_cvodes -lsundials_nvecserial ...
    -lgomp CFLAGS="\$CFLAGS -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp" ...
    hello_mex.c
mex -I/home/jhsong/usr/include -L/home/jhsong/usr/lib ...
    -lsundials_cvodes -lsundials_nvecserial ...
    -lgomp CFLAGS="\$CFLAGS -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp" ...
    hello_mex_mat.c
*/

