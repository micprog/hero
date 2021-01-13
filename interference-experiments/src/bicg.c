/* POLYBENCH/GPU-OPENACC
 *
 * This file is a part of the Polybench/GPU-OpenACC suite
 *
 * Contact:
 * William Killian <killian@udel.edu>
 *
 * Copyright 2013, The University of Delaware
 */
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>

/* Include polybench common header. */
#include <polybench.h>
#ifdef PREM
#include <cmux.c>
#endif

/* Include benchmark-specific header. */
/* Default data type is double, default size is 4000. */
#include "bicg.h"


/* Array initialization. */
static
void init_array (int nx, int ny,
                 DATA_TYPE POLYBENCH_2D(A,NX,NY,nx,ny),
                 DATA_TYPE POLYBENCH_1D(r,NX,nx),
                 DATA_TYPE POLYBENCH_1D(p,NY,ny))
{
  int i, j;

  for (i = 0; i < ny; i++)
    p[i] = i;// * M_PI;
  for (i = 0; i < nx; i++) {
    r[i] = i;// * M_PI;
    for (j = 0; j < ny; j++)
      A[i][j] = ((DATA_TYPE) i*(j+1))/nx;
  }
}


/* DCE code. Must scan the entire live-out data.
   Can be used also to check the correctness of the output. */
static
void print_array(int nx, int ny,
                 DATA_TYPE POLYBENCH_1D(s,NY,ny),
                 DATA_TYPE POLYBENCH_1D(q,NX,nx))

{
  int i;

  for (i = 0; i < ny; i++) {
    fprintf (stderr, DATA_PRINTF_MODIFIER, s[i]);
    if (i % 20 == 0) fprintf (stderr, "\n");
  }
  for (i = 0; i < nx; i++) {
    fprintf (stderr, DATA_PRINTF_MODIFIER, q[i]);
    if (i % 20 == 0) fprintf (stderr, "\n");
  }
  fprintf (stderr, "\n");
}


/* Main computational kernel. The whole function will be timed,
   including the call and return. */
static
void kernel_bicg(int nx, int ny,
                 DATA_TYPE POLYBENCH_2D(A,NX,NY,nx,ny),
                 DATA_TYPE POLYBENCH_1D(s,NY,ny),
                 DATA_TYPE POLYBENCH_1D(q,NX,nx),
                 DATA_TYPE POLYBENCH_1D(p,NY,ny),
                 DATA_TYPE POLYBENCH_1D(r,NX,nx))
{
  int i, j;
  //#pragma acc data copyout(s,q) copyin(A,r,p)
  #pragma omp target data \
    map(to: A[0:NX][0:NY], r[0:NX], p[0:NY]) \
    map(from: s[0:NY], q[0:NX])
  {
    /* q := A*p */
    //#pragma acc parallel present(q,A,p) \
                         num_gangs(nx/100) num_workers(100)
    {
      //#pragma acc loop gang worker
      #pragma omp target
      for (i = 0; i < NX; i++) {
        q[i] = 0;
        //#pragma acc loop seq
        for (j = 0; j < NY; j++)
          q[i] = q[i] + A[i][j] * p[j];
      }
    }
    /* s := r*A */
    //#pragma acc parallel present(s,r,A) \
                         num_gangs(ny/100) num_workers(100)
    {
      //#pragma acc loop gang worker
      #pragma omp target
      for (j = 0; j < NY; j++) {
        s[j] = 0;
        //#pragma acc loop seq
        for (i = 0; i < NX; i++)
          s[j] = s[j] + r[i] * A[i][j];
      }
    }
  }
}


int main(int argc, char** argv)
{
  // Set to high prio
  int prio = -20;
  if(nice(prio) != prio) {
    perror("Could not set priority\n");
  }


  /* Retrieve problem size. */
  int nx = NX;
  int ny = NY;

  /* Variable declaration/allocation. */
  POLYBENCH_2D_ARRAY_DECL(A, DATA_TYPE, NX, NY, nx, ny);
  POLYBENCH_1D_ARRAY_DECL(s, DATA_TYPE, NY, ny);
  POLYBENCH_1D_ARRAY_DECL(q, DATA_TYPE, NX, nx);
  POLYBENCH_1D_ARRAY_DECL(p, DATA_TYPE, NY, ny);
  POLYBENCH_1D_ARRAY_DECL(r, DATA_TYPE, NX, nx);

  /* Initialize array(s). */
  init_array (nx, ny,
              POLYBENCH_ARRAY(A),
              POLYBENCH_ARRAY(r),
              POLYBENCH_ARRAY(p));
#ifdef USEFLAG
  increment_flag(1);
#endif

  // Start timer.
  polybench_start_instruments;

#ifdef LOOPFOREVER
  for(int i=0;i<1;i=0){
#else
	#ifdef TIMEKERN
  clock_gettime(CLOCK_MONOTONIC_RAW, &KernStrt);
	#endif
#endif
 /* Run kernel. */
  kernel_bicg (nx, ny,
               POLYBENCH_ARRAY(A),
               POLYBENCH_ARRAY(s),
               POLYBENCH_ARRAY(q),
               POLYBENCH_ARRAY(p),
               POLYBENCH_ARRAY(r));
#ifdef LOOPFOREVER
	}
#else
	#ifdef TIMEKERN
  	clock_gettime(CLOCK_MONOTONIC_RAW, &KernStop);
	#endif
#endif
    /* Stop and print timer. */
  polybench_stop_instruments;
  polybench_print_instruments;

  /* Prevent dead-code elimination. All live-out data must be printed
     by the function call in argument. */
  polybench_prevent_dce(print_array(nx, ny, POLYBENCH_ARRAY(s), POLYBENCH_ARRAY(q)));

  /* Be clean. */
  POLYBENCH_FREE_ARRAY(A);
  POLYBENCH_FREE_ARRAY(s);
  POLYBENCH_FREE_ARRAY(q);
  POLYBENCH_FREE_ARRAY(p);
  POLYBENCH_FREE_ARRAY(r);
#ifdef TIMEKERN
	eval_kern_time(KernStrt, KernStop);
#endif
#ifdef USEFLAG
  increment_flag(-1);
#endif

  return 0;
}
