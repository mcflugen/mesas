# cython: profile=True
# -*- coding: utf-8 -*-
"""
.. module:: rsas
   :platform: Unix, Windows
   :synopsis: Time-variable transport using storage selection (SAS) functions

.. moduleauthor:: Ciaran J. Harman
"""

from __future__ import division
from f_solve import f_solve
import numpy as np
from warnings import warn
dtype = np.float64

# for debugging
DEBUG = False
VERBOSE = False


def _debug(statement):
    """Prints debuging messages if DEBUG==True

    """
    if DEBUG:
        print(statement, end='')


def _verbose(statement):
    """Prints debuging messages if VERBOSE==True

    """
    if VERBOSE:
        print(statement)


def make_lookup(rSAS_fun, N, P_list):
    numflux = len(rSAS_fun)
    rSAS_lookup = np.zeros((len(P_list), N, numflux))
    for i in range(N):
        for q in range(numflux):
            rSAS_lookup[:, i, q] = rSAS_fun[q].invcdf_i(P_list, i)
            rSAS_lookup[0, i, q] = rSAS_fun[q].ST_min[i]
    return rSAS_lookup


def solve(J, Q, rSAS_fun, mode='RK4', ST_init=None, dt=1, n_substeps=1, P_list=None,
          full_outputs=True, CS_init=None, C_J=None, alpha=None, k1=None, C_eq=None,  C_old=None, verbose=False, debug=False):
    """Solve the rSAS model for given fluxes

    Args:
        J : n x 1 float64 ndarray
            Timestep-averaged inflow timeseries for n timesteps
        Q : n x q float64 ndarray or list of length n 1D float64 ndarray
            Timestep-averaged outflow timeseries for n timesteps and q outflow fluxes. Must have same units and length as J.  For multiple outflows, each column represents one outflow
        rSAS_fun : rSASFunctionClass or list of rSASFunctionClass generated by rsas.create_function
            The number of rSASFunctionClass in this list must be the same as the
            number of columns in Q if Q is an ndarray, or elements in Q if it is a list.

    Kwargs:
        ST_init : m+1 x 1 float64 ndarray
            Initial condition for the age-ranked storage. The length of ST_init determines the maximum age calculated. The first entry must be 0 (corresponding to zero age). To calculate transit time dsitributions up to m timesteps in age, ST_init should have length m + 1. The default initial condition is ST_init=np.zeros(len(J) + 1).
        dt : float (default 1)
            Timestep, assuming same units as J
        n_substeps : int (default 1)
            If n_substeps>1, the timesteps are subdivided to allow a more accurate
            solution.
        full_outputs : bool (default True)
            Option to return the full state variables array ST the cumulative
            transit time distributions PQ, and other variables
        verbose : bool (default False)
            Print information about the progression of the model
        debug : bool (default False)
            Print information ever substep
        C_J : n x s float64 ndarray (default None)
            Optional timeseries of inflow concentrations for s solutes
        CS_init : s X 1 or m+1 x s float64 ndarray
            Initial condition for calculating the age-ranked solute mass. Must be a 2-D array the same length as ST_init or a 1-D array, where the concentration in storage is assumed to be constant for all ages.
        C_old : s x 1 float64 ndarray (default None)
            Optional concentration of the 'unobserved fraction' of Q (from inflows prior to the start of the simulation) for correcting C_Q. If ST_init is not given or set to all zeros, the unobserved fraction will be assumed for water that entered prior to time zero (diagonal of the PQ matrix).  Otherwise it will be used for water older than the oldest water in ST (the bottom row of the PQ matrix).
        alpha : n x q x s or q x s float64 ndarray
            Optional partitioning coefficient relating discharge concentrations cQ and storage concentration cS as cQ = alpha x cS. Alpha can be specified as a 2D q x s array if it is assumed to be constant, or as a n x q x s array if it is to vary in time.
        k1 : s x 1 or n x s float64 ndarray (default none)
            Optional first order reaction rate. May be specified as n x s if allowed to vary in time, or s x 1 if constant.
        C_eq : s x 1 or n x s float64 ndarray (default none)
            Optional equilibrium concentration for first-order reaction rate. Assumed to be 0 if omitted.
        P_list : p x 1 float64 ndarray
            This must be a monotonically increasing array of numbers from 0 to 1 (inclusive).
            Used to construct a lookup table for the rSAS function. Default is 101 uniformly spaced values

    Returns:
        A dict with the following keys:
            'ST' : m+1 x n+1 numpy float64 2D array
                Array of age-ranked storage for n times, m ages. (full_outputs=True only)
            'PQ' : m+1 x n+1 x q numpy float64 2D array
                List of time-varying cumulative transit time distributions for n times,
                m ages, and q fluxes. (full_outputs=True only)
            'WaterBalance' : m x n numpy float64 2D array
                Should always be within tolerances of zero, unless something is very
                wrong. (full_outputs=True only)
            'C_Q' : n x q x s float64 ndarray
                If C_J is supplied, C_Q is the timeseries of outflow concentration
            'MS' : m+1 x n+1 x s float64 ndarray
                Array of age-ranked solute mass for n times, m ages, and s solutes.
                (full_outputs=True only)
            'MQ' : m+1 x n+1 x q x s float64 ndarray
                Array of age-ranked solute mass flux for n times, m ages, q fluxes and s
                solutes. (full_outputs=True only)
            'MR' : m+1 x n+1 x s float64 ndarray
                Array of age-ranked solute reaction flux for n times, m ages, and s
                solutes. (full_outputs=True only)
            'SoluteBalance' : m x n x s float64 ndarray
                Should always be within tolerances of zero, unless something is very
                wrong. (full_outputs=True only)

    For each of the arrays in the full outputs each row represents an age, and each
    column is a timestep. For n timesteps and m ages, ST will have dimensions
    (n+1) x (m+1), with the first row representing age T = 0 and the first
    column derived from the initial condition.
    """
    # This function just does input checking
    # then calls the private implementation functions defined below
    global VERBOSE
    global DEBUG
    VERBOSE = verbose
    DEBUG = debug
    _verbose('Checking inputs...')
    if type(J) is not np.ndarray:
        J = np.array(J)
    if J.ndim != 1:
        raise TypeError('J must be a 1-D array')
    J = J.astype(np.float)
    timeseries_length = len(J)
    if type(Q) is not np.ndarray:
        Q = np.array(Q).T
    Q = Q.astype(np.float)
    if (Q.ndim > 2) or (Q.shape[0] != timeseries_length):
        raise TypeError(
            'Q must be a 1 or 2-D numpy array with a column for each outflow\nor a list of 1-D numpy arrays (like ''[Q1, Q2]'')\nand each must be the same size as J')
    elif Q.ndim == 1:
        Q = np.c_[Q]
    numflux = Q.shape[1]
    if ST_init is not None:
        if type(ST_init) is not np.ndarray:
            ST_init = np.array(ST_init)
        if ST_init.ndim != 1:
            raise TypeError('ST_init must be a 1-D array')
        if ST_init[0] != 0:
            raise TypeError('ST_init[0] must be 0')
    else:
        ST_init = np.zeros(timeseries_length+1)
    max_age = len(ST_init)-1
    if P_list is not None:
        if type(P_list) is not np.ndarray:
            P_list = np.array(P_list)
        if P_list.ndim != 1:
            raise TypeError('P_list must be a 1-D array')
        if P_list[-1] != 1:
            raise TypeError('P_list[-1] must be 1')
        if P_list[0] != 0:
            raise TypeError('P_list[0] must be 0')
        if not all(P_list[i] <= P_list[i+1] for i in xrange(len(P_list)-1)):
            raise TypeError('P_list must be sorted')
    else:
        P_list = np.linspace(0, 1, 101)
    nP_list = len(P_list)
    if type(rSAS_fun) is np.ndarray:
        if ((rSAS_fun.shape[0] == nP_list)
                and (rSAS_fun.shape[1] == timeseries_length)
                and (rSAS_fun.shape[2] == numflux)):
            _verbose('...assuming rSAS_fun is already rSAS_lookup...')
            rSAS_lookup = rSAS_fun
        else:
            raise TypeError('rSAS_lookup is wrong shape')
    else:
        if type(rSAS_fun) is not list:
            rSAS_fun = [rSAS_fun]
        if numflux != len(rSAS_fun):
            raise TypeError(
                'Each rSAS function must have a corresponding outflow in Q. Numbers don''t match')
        for fun in rSAS_fun:
            fun_methods = [method for method in dir(fun) if callable(getattr(fun, method))]
            if not ('cdf_all' in fun_methods and 'cdf_i' in fun_methods):
                raise TypeError(
                    'Each rSAS function must have methods rSAS_fun.cdf_all and rSAS_fun.cdf_i')
        _verbose('...making rsas lookup table rSAS_lookup...')
        rSAS_lookup = make_lookup(rSAS_fun, timeseries_length, P_list)
        _verbose('...done...')
    if type(full_outputs) is not bool:
        raise TypeError('full_outputs must be a boolean (True/False)')
    if C_J is not None:
        if type(C_J) is not np.ndarray:
            C_J = np.array(C_J, dtype=dtype)
        if ((C_J.ndim > 2) or (C_J.shape[0] != timeseries_length)):
            raise TypeError(
                'C_J must be a 1 or 2-D array with a first dimension the same length as J')
        elif C_J.ndim == 1:
            C_J = np.c_[C_J]
        C_J = C_J.astype(np.float)
    else:
        C_J = np.zeros((timeseries_length, 1))
    numsol = C_J.shape[1]
    if alpha is not None:
        if type(alpha) is not np.ndarray:
            alpha = np.array(alpha, dtype=dtype)
        if alpha.ndim == 2:
            alpha = np.tile(alpha, (timeseries_length, 1, 1))
        if (alpha.shape[2] != numsol) and (alpha.shape[1] != numflux):
            raise TypeError("alpha array dimensions don't match other inputs")
        alpha = alpha.astype(dtype)
    else:
        alpha = np.ones((timeseries_length, numflux, numsol))
    if k1 is not None:
        if type(k1) is not np.ndarray:
            k1 = np.array(k1, dtype=dtype)
        if k1.ndim == 1 and len(k1) == numsol:
            k1 = np.tile(k1, (timeseries_length, 1))
        if (k1.shape[1] != numsol) and (k1.shape[0] != timeseries_length):
            raise TypeError("k1 array dimensions don't match other inputs")
        k1 = k1.astype(dtype)
    else:
        k1 = np.zeros((timeseries_length, numsol))
    if C_eq is not None:
        if type(C_eq) is not np.ndarray:
            C_eq = np.array(C_eq, dtype=dtype)
        if C_eq.ndim == 1 and len(C_eq) == numsol:
            C_eq = np.tile(C_eq, (timeseries_length, 1))
        if (C_eq.shape[1] != numsol) and (C_eq.shape[0] != timeseries_length):
            raise TypeError("C_eq array dimensions don't match other inputs")
        C_eq = C_eq.astype(dtype)
    else:
        C_eq = np.zeros((timeseries_length, numsol))
    if C_old is not None:
        if type(C_old) is not np.ndarray:
            C_old = np.array(C_old, dtype=dtype)
        if len(C_old) != numsol:
            raise TypeError('C_old must have the same number of entries as C_J has columns')
        C_old = C_old.astype(dtype)
    else:
        C_old = np.zeros(numsol)
    if CS_init is not None:
        if type(CS_init) is not np.ndarray:
            CS_init = np.array(CS_init, dtype=dtype)
        if CS_init.ndim == 1:
            CS_init = np.tile(CS_init, (max_age-1, 1))
        if (CS_init.shape[1] != numsol) and (CS_init.shape[0] != max_age):
            raise TypeError("CS_init array dimensions don't match other inputs")
        CS_init = CS_init.astype(dtype)
    else:
        CS_init = np.zeros((max_age, numsol))
    if dt is not None:
        dt = np.float64(dt)
    if n_substeps is not None:
        n_substeps = np.int(n_substeps)
    if full_outputs is False and C_J is None:
        warn('No output will be generated! Are you sure you mean to do this?')
    # Run implemented solvers
    _verbose('Running rsas...')
    if mode == 'age':
        warn('mode age is deprecated, switching to RK4')
        mode = 'RK4'
    if mode == 'time':
        warn('mode time is deprecated, switching to RK4')
        mode = 'RK4'
    if mode == 'RK4':
        # result = _solve_RK4(J, Q, rSAS_fun, ST_init=ST_init,
        #                    dt=dt, n_substeps=n_substeps,
        #                    full_outputs=full_outputs,
        #                    CS_init=CS_init, C_J=C_J, alpha=alpha, k1=k1, C_eq=C_eq, C_old=C_old)
        fresult = f_solve(
            J, Q, rSAS_lookup, P_list, ST_init, dt,
            verbose, debug, full_outputs,
            CS_init, C_J, alpha, k1, C_eq, C_old,
            n_substeps, numflux, numsol, max_age, timeseries_length,  nP_list)
        _verbose('... done')
        ST, PQ, WaterBalance, MS, MQ, MR, C_Q, SoluteBalance = fresult
    else:
        raise TypeError('Invalid solution mode.')

    _verbose('...making output dict...')
    if numsol > 0:
        result = {'C_Q': C_Q}
    else:
        result = {}
    if full_outputs:
        if numsol > 0:
            result.update({'ST': ST, 'PQ': PQ, 'WaterBalance': WaterBalance, 'MS': MS, 'MQ': MQ, 'MR': MR,
                           'C_Q': C_Q, 'SoluteBalance': SoluteBalance, 'P_list': P_list, 'rSAS_lookup': rSAS_lookup})
        else:
            result.update({'ST': ST, 'PQ': PQ, 'WaterBalance': WaterBalance,
                           'P_list': P_list, 'rSAS_lookup': rSAS_lookup})
    return result
