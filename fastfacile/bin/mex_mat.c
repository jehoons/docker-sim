/* cmex simulation framework - matrix version. This version is different 
 * with *_mex.c in that the engine returns matrix  data.  
 * Version 1.1
 * Author: Je-Hoon Song, Email: song.jehoon@gmail.com
 * Last update: 2015_1126
 *
 * use following command to compile in matlab: 
 * %build model: 
 *
 * mex -I/home/jhsong/usr/include 
 *      -L/home/jhsong/usr/lib 
 *      -lsundials_cvodes 
 *      -lsundials_nvecserial 
 *      -lgomp CFLAGS="\$CFLAGS 
 *      -fopenmp" LDFLAGS="\$LDFLAGS 
 *      -fopenmp" hello_mex.c mex 
 *      -I/home/jhsong/usr/include 
 *      -L/home/jhsong/usr/lib 
 *      -lsundials_cvodes 
 *      -lsundials_nvecserial
 *      -lgomp CFLAGS="\$CFLAGS 
 *      -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp"
 *      hello_mex_mat.c
 *  */
#ifdef MATLAB
#   include "mex.h"
#endif
#include "math.h"
#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include <time.h>
#include <stddef.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <assert.h>
#include <sundials/sundials_types.h>
#include <sundials/sundials_dense.h>
#include <sundials/sundials_nvector.h>
#include <nvector/nvector_serial.h>
#include <cvode/cvode.h>
#include <cvode/cvode_dense.h>
#include <omp.h>
#include <gsl/gsl_rng.h>
#include "ode_size.h"
#include "$(MODEL)_cv.c"

#define PACKAGE_SIZE   (10) 
#define THREAD_NUM     (64)

#define SOLVER_ABS_ERROR    1.0e-8
#define SOLVER_REL_ERROR    1.0e-7
/*#define MAX_STEPS           1.0e+8*/
#define MAX_STEPS           1.0e+5
#define MAX_SOLVER_TRY      1




#ifdef MATLAB
void transp(mxArray*dest, const mxArray*src);
#endif 


#ifdef LANGEVIN
double noise2(gsl_rng *r, double x, double zeta);
#endif 


int engine(
        int num_timepoints, 
        double *ptr_timepoints, 
        int num_samples_rates, 
        int num_species_ival, 
        double *ivalues_array, 
        int num_params_rates, 
        double *rates_array, 
        double *y_array, 
        double *yss_array, 
        double *ptr_output_flag
#ifdef LANGEVIN
        ,double zeta
#endif 
        );


int worker(
        double *tvec, 
        int tvec_size, 
        int num_species, 
        int num_parameter, 
        realtype *ivalues, 
        realtype *rates, 
        double* output_y, 
        double* output_yss,
        gsl_rng* rng
#ifdef LANGEVIN
        , double zeta
#endif 
        ) 
{
    int i, j, cvode_flag;

    char *solver_param_names_[4] = { 
        "abserr", 
        "relerr", 
        "stoptime", 
        "maxsteps" 
    };

    realtype solver_param_[4] = { 
        RCONST(SOLVER_ABS_ERROR), 
        RCONST(SOLVER_REL_ERROR), 
        RCONST(tvec[tvec_size-1]), 
        RCONST(MAX_STEPS) 
    };

#define Ydynamics(ti,y) output_y[(ti)*num_species + (y)]
#define Ysteady(ith) output_yss[ith]

    /* For non-stiff problems: */
    /* void *cvode_mem = CVodeCreate(CV_ADAMS, CV_FUNCTIONAL); */

    /* For stiff problems: */
    void *cvode_mem = CVodeCreate(CV_BDF, CV_NEWTON);

    N_Vector yt;
    yt = N_VNew_Serial(num_species);

    for (i = 0; i < num_species; ++i)
        NV_Ith_S(yt, i) = ivalues[i];

    realtype t = RCONST(0.0); 

    int tidx = 0; 
    int num_try = 1;

    cvode_flag = CVodeMalloc(
            cvode_mem, 
            $(MODEL)_vf, 
            t, 
            yt, 
            CV_SS, 
            solver_param_[1], 
            &(solver_param_[0])
            );

    cvode_flag = CVodeSetFdata(
            cvode_mem, 
            &(rates[0])
            );

    cvode_flag = CVDense(
            cvode_mem, 
            num_species
            );

    cvode_flag = CVDenseSetJacFn(
            cvode_mem, 
            $(MODEL)_jac, 
            &(rates[0])
            );

    cvode_flag = CVodeSetStopTime(
            cvode_mem, 
            solver_param_[2]
            );

    while(tidx < tvec_size && num_try <= MAX_SOLVER_TRY) {
        t = RCONST(0.0);
        for (tidx = 0; tidx < tvec_size; ++tidx) {
            double tout = tvec[tidx];
            if (tout == 0) {
#ifndef STEADY
                for (j = 0; j < num_species; ++j)
                    Ydynamics(tidx, j) = NV_Ith_S(yt, j); 
#endif

            } else {
                /* Advance the solution */
                cvode_flag = CVode(cvode_mem, tout, yt, &t, CV_NORMAL);
                if (cvode_flag != CV_SUCCESS && cvode_flag != CV_TSTOP_RETURN) {
                    fprintf(stderr, "cvode_flag=%d (%dth try)\n", cvode_flag, 
                            num_try++);
                    break;
                }

                for (j = 0; j < num_species; ++j) {
#ifdef LANGEVIN
                    NV_Ith_S(yt, j) += noise2(rng, NV_Ith_S(yt, j), zeta); 
                    if(NV_Ith_S(yt, j) < 0.0)
                        NV_Ith_S(yt, j) = 0.0; 
#endif
#ifndef STEADY
                    Ydynamics(tidx, j) = NV_Ith_S(yt, j); 
#endif
                }
            } 
        } 
    }

    for (j = 0; j < num_species; ++j) 
        Ysteady(j) = NV_Ith_S(yt, j); 

    N_VDestroy_Serial(yt);
    CVodeFree(&cvode_mem);

    return cvode_flag; 
}



#if 0
double noise(gsl_rng *rng, double molar) 
{
#define AVOGADRO 6.022E+23
/* micro */
#ifdef MOLAR_UNIT_U 
#   define MOLAR_UNIT 1.0E-6
#endif
/* nano */
#ifdef MOLAR_UNIT_N 
#   define MOLAR_UNIT 1.0E-9
#endif
#ifndef VOLUME_IN_LITER
/* HEK293 with 1/3 cyoplasmic volume of it. */
#   define VOLUME_IN_LITER 1.0E-12 
#endif
#ifdef MOLAR_UNIT
    double zeta = MOLAR_UNIT*AVOGADRO*VOLUME_IN_LITER; 
#else
    double zeta = 1.0; 
#endif
    double u = gsl_rng_uniform(rng);
    double v = gsl_rng_uniform(rng); 
    double gau1 = sqrt(-2.0*log(u))*cos(2.0*M_PI*v);
    /*double gau2 = sqrt(-2.0*log(u))*sin(2.0*M_PI*v);*/
    return sqrt(molar*zeta)*gau1/zeta;
}
#endif 



/* if the unit of zeta is concentration, then 
 * zeta should be calculated by following equation: 
 *  zeta = MOLAR_UNIT*AVOGADRO*VOLUME_IN_LITER 
 * if zeta is the number of particles, then 
 *  zeta = 1.0
 * */
#ifdef LANGEVIN
double noise2(gsl_rng *rng, double molar, double zeta) 
{
    double u = gsl_rng_uniform(rng);
    double v = gsl_rng_uniform(rng); 
    double gau1 = sqrt(-2.0*log(u))*cos(2.0*M_PI*v);
    /*double gau2 = sqrt(-2.0*log(u))*sin(2.0*M_PI*v);*/
    return sqrt(molar*zeta)*gau1/zeta;
}
#endif 




#ifdef MATLAB 
void mexFunction(
        int nlhs, mxArray *plhs[],
        int nrhs, const mxArray *prhs[]
        )
{

#ifndef STEADY
#   define OUT_Y_T plhs[0]
#   define OUT_YSS_T plhs[1]
#   define OUT_FLAG plhs[2]
#else 
#   define OUT_YSS_T plhs[0]
#   define OUT_FLAG plhs[1]
#endif

#define TIME_VECTOR prhs[0]
#define INP_IVALUES prhs[1]
#define INP_RATES prhs[2]
#define INP_ZETA prhs[3]

    int i = 0, j = 0; 
    /* check the dimensions of input and output */
    if(nlhs!=2 && nlhs!=1 && nlhs!=3) {
        mexErrMsgTxt("Wrong number of output arguments.");
    }

    double zeta = 0.0;

    if (nrhs == 3) {
        #define AVOGADRO 6.02214E+23
        #define DEFAULT_MOLAR_UNIT 1.0E-9 /* nano mole */
        /* HEK293 with 1/3 cyoplasmic volume of it. */
        #define DEFAULT_VOLUME_IN_LITER 1.0E-12 
        zeta = DEFAULT_MOLAR_UNIT*AVOGADRO*DEFAULT_VOLUME_IN_LITER;
#ifdef LANGEVIN
    } else if (nrhs == 4) {
        zeta = *((double*) mxGetPr(INP_ZETA));
#endif
    } else {
        mexErrMsgTxt("Wrong number of input arguments.");
    }

    int num_timepoints = mxGetN(TIME_VECTOR); 
    double *ptr_timepoints = mxGetPr(TIME_VECTOR); 

    if(mxGetM(TIME_VECTOR) != 1) {
        mexErrMsgTxt("TIME_VECTOR should be 1 x ? vector!\n");
    }

    if(num_timepoints < 3) {
        mexErrMsgTxt("num_timepoints should be at least 3!\n");
    }

    int num_samples_ival = mxGetM(INP_IVALUES);
    int num_species_ival = mxGetN(INP_IVALUES);

    mxArray *INP_IVALUES_T = mxCreateDoubleMatrix(
            num_species_ival, 
            num_samples_ival, 
            mxREAL
            ); 

    double *ivalues_array = mxGetPr(INP_IVALUES_T);

    transp(INP_IVALUES_T, INP_IVALUES); 

    /* check the dimensions of rates */

    int num_samples_rates = mxGetM(INP_RATES); 
    int num_params_rates = mxGetN(INP_RATES);

    mxArray *INP_RATES_T = mxCreateDoubleMatrix(
            mxGetN(INP_RATES),
            mxGetM(INP_RATES), 
            mxREAL
            );

    double *rates_array = mxGetPr(INP_RATES_T);

    transp(INP_RATES_T, INP_RATES); 

    if(num_samples_rates != num_samples_ival) {
        mexPrintf("num_samples_rates = %d, num_samples_ival = %d\n", 
                num_samples_rates, 
                num_species_ival);

        mexErrMsgTxt("num_samples_rates is not same as the num_samples_ival\n");
    }

#ifdef STEADY 
    double *y_array = NULL; 
#else
    mxArray *OUT_Y = mxCreateDoubleMatrix(
            num_species_ival, 
            num_timepoints*num_samples_ival, 
            mxREAL
            );

    double *y_array = mxGetPr(OUT_Y); 
#endif 

    OUT_FLAG = mxCreateDoubleMatrix(
            num_samples_ival,
            1,
            mxREAL
            ); 

    double *ptr_output_flag = mxGetPr(OUT_FLAG);

    mxArray *OUT_YSS = mxCreateDoubleMatrix(
            num_species_ival,
            num_samples_ival,
            mxREAL
            ); 

    double *yss_array = mxGetPr(OUT_YSS); 

    if(num_species_ival != __N_SPECIES__)
        mexErrMsgTxt("wrong number of initials\n");

    if(num_params_rates != __N_PARAMETERS__)
        mexErrMsgTxt("wrong number of rates\n");

    engine(
            num_timepoints, 
            ptr_timepoints, 
            num_samples_rates,
            num_species_ival,
            ivalues_array, 
            num_params_rates, 
            rates_array,
            y_array,
            yss_array,
            ptr_output_flag
#ifdef LANGEVIN
            ,zeta
#endif 
            ); 

    OUT_YSS_T = mxCreateDoubleMatrix(
            num_samples_ival, 
            num_species_ival, 
            mxREAL
            );

    transp(OUT_YSS_T, OUT_YSS);

#ifndef STEADY
    OUT_Y_T = mxCreateDoubleMatrix(
            num_samples_ival*num_timepoints, 
            num_species_ival, 
            mxREAL
            );

    transp(OUT_Y_T, OUT_Y);
#endif

    mxDestroyArray(OUT_YSS); 
#ifndef STEADY    
    mxDestroyArray(OUT_Y);
#endif
    mxDestroyArray(INP_IVALUES_T); 
    mxDestroyArray(INP_RATES_T); 

    return;
}
#endif /* MATLAB */ 




int engine(
        int num_timepoints,
        double *ptr_timepoints, /* 1 x num_timepoints */
        int num_samples_rates, 
        int num_species_ival, 
        double *ivalues_array, 
        int num_params_rates, 
        double *rates_array, 
        double *y_array, 
        double *yss_array, 
        double *ptr_output_flag
#ifdef LANGEVIN 
        , double zeta
#endif
        )
{

    int i,j; 

    int chunk_size = PACKAGE_SIZE; 

    if (chunk_size == 0) chunk_size = 1; 

    if (chunk_size == 1) { 
        omp_set_num_threads(1); 
    } else {
        omp_set_num_threads(THREAD_NUM); /* bug??? */
    }

    gsl_rng *rng = gsl_rng_alloc(gsl_rng_mt19937);
    long seed = time(NULL)*getpid();
    gsl_rng_set(rng, seed); 

    if (THREAD_NUM == -1) 
        omp_set_num_threads(omp_get_max_threads()); 
    else
        omp_set_num_threads(THREAD_NUM);

    /* too many outputs will be repressed by following code */
    FILE *freopenResult = freopen("/dev/null","w",stderr);

#ifdef WITH_OMP
#pragma omp parallel for shared(chunk_size, num_samples_rates,ptr_timepoints,\
        num_timepoints, num_species_ival,num_params_rates,rates_array,\
        ivalues_array,yss_array) private (j,i)
#endif
    for (j = 0; j < num_samples_rates; j += chunk_size) {
        for(i = j; i <= j + chunk_size - 1 ; ++i) {
            if(i >= num_samples_rates) 
                continue; 
#define IVALUES_ARRAY(k) &ivalues_array[0 + (k)*num_species_ival] 
#define RATES_ARRAY(k) &rates_array[0 + (k)*num_params_rates] 
#define OUTPUT_Y_ARRAY(k) &y_array[0 + (k)*num_timepoints*num_species_ival]
#define OUTPUT_YSS_ARRAY(k) &yss_array[0 + (k)*num_species_ival]
            ptr_output_flag[i] = (double) worker( 
                    ptr_timepoints, 
                    num_timepoints, 
                    num_species_ival, 
                    num_params_rates, 
                    IVALUES_ARRAY(i), 
                    RATES_ARRAY(i), 
#ifndef STEADY 
                    OUTPUT_Y_ARRAY(i), 
#else
                    NULL, 
#endif
                    OUTPUT_YSS_ARRAY(i), 
                    rng
#ifdef LANGEVIN
                    ,zeta
#endif
                    );
        }
    }

    freopenResult = freopen("/dev/tty","w",stderr);

    gsl_rng_free(rng);

    return 0; 
}




#ifdef MATLAB
void transp(mxArray* dest, const mxArray* src) {
    int i, j; 
    int numRows = (int) mxGetM(src);
    int numCols = (int) mxGetN(src);

#ifdef WITH_OMP
#pragma omp parallel for shared(numCols, numRows, dest, src) private (j,i)
#endif
    for(j = 0; j < numCols; j++) {
        for(i = 0; i < numRows; i++) {
            mxGetPr(dest)[numCols*i + j] = mxGetPr(src)[numRows*j + i];
        }
    }

}
#endif /* MATLAB*/

