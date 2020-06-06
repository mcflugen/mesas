! -*- f90 -*-
subroutine solve(J_ts, Q_ts, SAS_lookup, P_list, weights_ts, sT_init_ts, dt, &
        verbose, debug, warning, &
        mT_init_ts, C_J_ts, alpha_ts, k1_ts, C_eq_ts, C_old, &
        n_substeps, nC_list, nP_list, numflux, numsol, max_age, &
        timeseries_length, nC_total, nP_total, &
        sT_ts, pQ_ts, WaterBalance_ts, &
        mT_ts, mQ_ts, mR_ts, C_Q_ts, ds_ts, dm_ts, dC_ts, SoluteBalance_ts)
    implicit none

    ! Start by declaring and initializing all the variables we will be using
    integer, intent(in) :: n_substeps, numflux, numsol, max_age, &
            timeseries_length, nC_total, nP_total
    real(8), intent(in), dimension(0:timeseries_length - 1) :: J_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:numflux - 1) :: Q_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:nC_total - 1) :: weights_ts
    real(8), intent(in), dimension(0:nP_total - 1, 0:timeseries_length - 1) :: SAS_lookup
    real(8), intent(in), dimension(0:nP_total - 1, 0:timeseries_length - 1) :: P_list
    real(8), intent(in), dimension(0:max_age - 1) :: sT_init_ts
    real(8), intent(in) :: dt
    logical, intent(in) :: verbose, debug, warning
    real(8), intent(in), dimension(0:max_age - 1, 0:numsol - 1) :: mT_init_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:numsol - 1) :: C_J_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:numflux - 1, 0:numsol - 1) :: alpha_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:numsol - 1) :: k1_ts
    real(8), intent(in), dimension(0:timeseries_length - 1, 0:numsol - 1) :: C_eq_ts
    real(8), intent(in), dimension(0:numsol - 1) :: C_old
    integer, intent(in), dimension(0:numflux - 1) :: nC_list
    integer, intent(in), dimension(0:nC_total - 1) :: nP_list
    real(8), intent(out), dimension(0:timeseries_length - 1, 0:numflux - 1, 0:numsol - 1) :: C_Q_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length) :: sT_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length, 0:numsol - 1) :: mT_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length, 0:nP_total-1) :: ds_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length, 0:nP_total-1, 0:numsol - 1) :: dm_ts
    real(8), intent(out), dimension(0:timeseries_length-1, 0:nP_total-1, 0:numflux - 1, 0:numsol - 1) :: dC_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length - 1, 0:numflux - 1) :: pQ_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length - 1, 0:numsol - 1) :: mR_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length - 1) :: WaterBalance_ts
    real(8), intent(out), dimension(0:max_age - 1, 0:timeseries_length - 1, 0:numsol - 1) :: SoluteBalance_ts
    integer :: k, iT, jt, ik, jk, i_prev, js
    real(8) :: h
    real(8), dimension(0:timeseries_length-1, 0:nP_total-1, 0:numflux - 1) :: dW_ts
    real(8), dimension(0:timeseries_length - 1, 0:numflux - 1) :: P_old
    integer, dimension(0:nC_total) :: iP_list
    integer, dimension(0:numflux) :: iC_list
    real(8), dimension(0:timeseries_length * n_substeps, 0:numsol - 1) :: CS_last
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: J_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: C_J_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: Q_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: alpha_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: C_eq_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: k1_ss
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nC_total - 1) :: weights_ss
    real(8), dimension(0:timeseries_length * n_substeps) :: STcum_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: STcum_end
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: STcum_start
    real(8), dimension(0:timeseries_length * n_substeps, 0:numflux - 1) :: PQcum_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: PQcum_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: PQcum_start
    integer, dimension(0:timeseries_length * n_substeps, 0:nC_total-1) :: iPj_prev
    integer, dimension(0:timeseries_length * n_substeps - 1, 0:nC_total-1) :: iPj_end
    integer, dimension(0:timeseries_length * n_substeps - 1, 0:nC_total-1) :: iPj_start
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR1
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR2
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR3
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR4
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR_aver
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: sT_start
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: sT_temp
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: sT_end
    real(8), dimension(0:timeseries_length * n_substeps - 1) :: sT_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_start
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_temp
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1) :: ds_start
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1) :: ds_temp
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1) :: ds_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1) :: ds_prev
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1, 0:numsol - 1) :: dm_start
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1, 0:numsol - 1) :: dm_temp
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1, 0:numsol - 1) :: dm_end
    real(8), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total-1, 0:numsol - 1) :: dm_prev
    real(8) :: one8, norm
    real(8) :: dS, dP, dSe, dPe, dSs, dPs
    character(len = 128) :: tempdebugstring
    integer :: iq, s, M, N, ip, ic, kk, rightend
    logical :: carryover

    call f_verbose('...Initializing arrays...')
    one8 = 1.0

    C_Q_ts(:, :, :) = 0.
    sT_ts(:, :) = 0.
    mT_ts(:, :, :) = 0.
    ds_ts(:, :, :) = 0.
    dm_ts(:, :, :, :) = 0.
    dC_ts(:, :, :, :) = 0.
    dW_ts(:, :, :) = 0.
    pQ_ts(:, :, :) = 0.
    mQ_ts(:, :, :, :) = 0.
    mR_ts(:, :, :) = 0.
    WaterBalance_ts(:, :) = 0.
    SoluteBalance_ts(:, :, :) = 0.
    P_old(:, :) = 0.
    iP_list(:) = 0
    iC_list(:) = 0
    STcum_prev(:) = 0.
    STcum_end(:) = 0.
    STcum_start(:) = 0.
    PQcum_prev(:, :) = 0.
    PQcum_end(:, :) = 0.
    PQcum_start(:, :) = 0.
    iPj_prev(:, :) = 0
    iPj_end(:, :) = 0
    iPj_start(:, :) = 0
    pQ1(:, :) = 0.
    pQ2(:, :) = 0.
    pQ3(:, :) = 0.
    pQ4(:, :) = 0.
    pQ_aver(:, :) = 0.
    pQ_end(:, :) = 0.
    pQ_prev(:, :) = 0.
    mQ1(:, :, :) = 0.
    mQ2(:, :, :) = 0.
    mQ3(:, :, :) = 0.
    mQ4(:, :, :) = 0.
    mQ_aver(:, :, :) = 0.
    mQ_end(:, :, :) = 0.
    mQ_prev(:, :, :) = 0.
    mR1(:, :) = 0.
    mR2(:, :) = 0.
    mR3(:, :) = 0.
    mR4(:, :) = 0.
    mR_aver(:, :) = 0.
    mR_end(:, :) = 0.
    mR_prev(:, :) = 0.
    fs1(:, :) = 0.
    fs2(:, :) = 0.
    fs3(:, :) = 0.
    fs4(:, :) = 0.
    fs_aver(:, :) = 0.
    fs_end(:, :) = 0.
    fs_prev(:, :) = 0.
    fm1(:, :, :) = 0.
    fm2(:, :, :) = 0.
    fm3(:, :, :) = 0.
    fm4(:, :, :) = 0.
    fm_aver(:, :, :) = 0.
    fm_end(:, :, :) = 0.
    fm_prev(:, :, :) = 0.
    fmR1(:, :, :) = 0.
    fmR2(:, :, :) = 0.
    fmR3(:, :, :) = 0.
    fmR4(:, :, :) = 0.
    fmR_aver(:, :, :) = 0.
    fmR_end(:, :, :) = 0.
    fmR_prev(:, :, :) = 0.
    sT_start(:) = 0.
    sT_temp(:) = 0.
    sT_end(:) = 0.
    sT_prev(:) = 0.
    mT_start(:, :) = 0.
    mT_temp(:, :) = 0.
    mT_end(:, :) = 0.
    mT_prev(:, :) = 0.
    ds_start(:, :) = 0.
    ds_temp(:, :) = 0.
    ds_end(:, :) = 0.
    ds_prev(:, :) = 0.
    dm_start(:, :, :) = 0.
    dm_temp(:, :, :) = 0.
    dm_end(:, :, :) = 0.
    dm_prev(:, :, :) = 0.
    CS_last(:, :) = 0.
    i_prev = -1

    ! The list of probabilities in each sas function is a 1-D array.
    ! iP_list gives the starting index of the probabilities (P) associated
    ! with each flux
    iP_list(0) = 0
    iC_list(0) = 0
    do iq = 0, numflux - 1
        iC_list(iq + 1) = iC_list(iq) + nC_list(iq)
        do ic = iC_list(iq), iC_list(iq+1) - 1
            iP_list(ic + 1) = iP_list(ic) + nP_list(ic)
        enddo
    enddo
    !call f_debug('iP_list', one8 * iP_list(:))

    ! modify the number of ages and the timestep by a facotr of n_substeps
    M = max_age * n_substeps
    N = timeseries_length * n_substeps
    h = dt / n_substeps

    J_ss = reshape(spread(J_ts, 1, n_substeps), (/N/))
    C_J_ss = reshape(spread(C_J_ts, 1, n_substeps), (/N, numsol/))
    Q_ss = reshape(spread(Q_ts, 1, n_substeps), (/N, numflux/))
    alpha_ss = reshape(spread(alpha_ts, 1, n_substeps), (/N, numflux, numsol/))
    C_eq_ss = reshape(spread(C_eq_ts, 1, n_substeps), (/N, numsol/))
    k1_ss = reshape(spread(k1_ts, 1, n_substeps), (/N, numsol/))
    weights_ss = reshape(spread(weights_ts, 1, n_substeps), (/N, nC_total/))
    !call f_debug('J_ss           ', J_ss)
    do s = 0, numsol - 1
        !call f_debug('C_J_ss           ', C_J_ss(:, s))
    end do
    do iq = 0, numflux - 1
        !call f_debug('Q_ss           ', Q_ss(:,iq))
    end do

    call f_verbose('...Setting initial conditions...')
    sT_ts(:, 0) = sT_init_ts
    do s = 0, numsol - 1
        mT_ts(:, 0, s) = mT_init_ts(:, s)
    end do

    call f_verbose('...Starting main loop...')
    do iT = 0, max_age - 1

        ! Start the substep loop
        do k = 0, n_substeps - 1

            ik = iT * n_substeps + k

            call f_debug_blank()
            call f_debug_blank()
            call f_debug('Agestep, Substep', (/ iT * one8, k * one8/))
            call f_debug_blank()

            ! Copy the state variables from the end of the previous substep as the start of this one
            ! but shifted by one substep
            sT_start(1:N - 1) = sT_end(0:N - 2)
            mT_start(1:N - 1, :) = mT_end(0:N - 2, :)
            ds_start(1:N - 1, :) = ds_end(0:N - 2, :)
            dm_start(1:N - 1, :, :) = dm_end(0:N - 2, :, :)
            ! Initialize the value at t=0
            if (ik>0) then
                sT_start(0) = sT_init_ts(i_prev)
                mT_start(0, :) = mT_init_ts(i_prev, :)
                ds_start(0, :) = 0.
                dm_start(0, :, :) = 0.
            end if

            ! These will hold the evolving state variables
            ! They are global variables modified by the new_state function

            ! This is the Runge-Kutta 4th order algorithm

            call f_debug('RK', (/1._8/))
            sT_temp = sT_start
            mT_temp = mT_start
            ds_temp = ds_start
            dm_temp = dm_start
            call get_flux(0.0D0, sT_temp, mT_temp, ds_temp, dm_temp, pQ1, mQ1, mR1, fs1, fm1, fmR1)
            !call f_debug_blank()
            call f_debug('RK', (/2._8/))
            call new_state(h / 2, sT_temp, mT_temp, ds_temp, dm_temp, pQ1, mQ1, mR1, fs1, fm1, fmR1)
            call get_flux(h / 2, sT_temp, mT_temp, ds_temp, dm_temp, pQ2, mQ2, mR2, fs2, fm2, fmR2)
            !call f_debug_blank()
            call f_debug('RK', (/3._8/))
            call new_state(h / 2, sT_temp, mT_temp, ds_temp, dm_temp, pQ2, mQ2, mR2, fs2, fm2, fmR2)
            call get_flux(h / 2, sT_temp, mT_temp, ds_temp, dm_temp, pQ3, mQ3, mR3, fs3, fm3, fmR3)
            !call f_debug_blank()
            call f_debug('RK', (/4._8/))
            call new_state(h, sT_temp, mT_temp, ds_temp, dm_temp, pQ3, mQ3, mR3, fs3, fm3, fmR3)
            call get_flux(h, sT_temp, mT_temp, ds_temp, dm_temp, pQ4, mQ4, mR4, fs4, fm4, fmR4)

            ! Average RK4 estimated change in the state variables
            pQ_aver = (pQ1 + 2 * pQ2 + 2 * pQ3 + pQ4) / 6.
            mQ_aver = (mQ1 + 2 * mQ2 + 2 * mQ3 + mQ4) / 6.
            mR_aver = (mR1 + 2 * mR2 + 2 * mR3 + mR4) / 6.
            fs_aver = (fs1 + 2 * fs2 + 2 * fs3 + fs4) / 6.
            fm_aver = (fm1 + 2 * fm2 + 2 * fm3 + fm4) / 6.
            fmR_aver = (fmR1 + 2 * fmR2 + 2 * fmR3 + fmR4) / 6.

            ! zero out the probabilities if there is no outflux this timestep
            where (Q_ss==0)
                pQ_aver = 0.
            end where
            do s = 0, numsol - 1
                where (Q_ss==0)
                    mQ_aver(:, :, s) = 0.
                end where
            end do

            call f_debug('RK final', (/4._8/))
            call f_debug('pQ_aver        ', pQ_aver(:,0))
            ! Update the state with the new estimates
            call new_state(h, sT_end, mT_end, ds_end, dm_end, pQ_aver, mQ_aver, mR_aver, fs_aver, fm_aver, fmR_aver)

            ! output some debugging info if desired
            do iq = 0, numflux - 1
                !call f_debug('pQ_aver        ', pQ_aver(:, iq))
            enddo
            do s = 0, numsol - 1
                !call f_debug('mT_end         ', mT_end(:, s))
                !call f_debug('mR_aver        ', mR_aver(:, s))
                do iq = 0, numflux - 1
                    !call f_debug('mQ_aver        ', mQ_aver(:, iq, s))
                enddo
            enddo

            ! Aggregate flux data from substep to timestep

            ! Get the timestep-averaged transit time distribution
            norm = 1.0 / n_substeps / n_substeps
            carryover = ((n_substeps>1) .and. (k>0) .and. (iT<max_age-1))
            do iq = 0, numflux - 1
                do jt = 0, timeseries_length - 1
                    js = jt * n_substeps
                    pQ_ts(iT, jt, iq) = pQ_ts(iT, jt, iq) + sum(pQ_aver((js+k):(js+n_substeps-1), iq)) * norm
                    if (carryover) then
                        pQ_ts(iT+1, jt, iq) = pQ_ts(iT+1, jt, iq) + sum(pQ_aver((js):(js+k-1), iq)) * norm
                    endif
                enddo
                do ip = 0, nP_total - 1
                    do jt = 0, timeseries_length - 1
                        if (Q_ts(jt, iq)>0) then
                            js = jt * n_substeps
                            dW_ts(jt, ip, iq) = dW_ts(jt, ip, iq) &
                                    + sum(fs_aver((js+k):(js+n_substeps-1), ip))/Q_ts(jt, iq) * norm * dt
                            if (carryover) then
                                dW_ts(jt, ip, iq) = dW_ts(jt, ip, iq) &
                                        + sum(fs_aver((js):(js+k-1), ip))/Q_ts(jt, iq) * norm * dt
                            endif
                        endif
                    enddo
                enddo
                do s = 0, numsol - 1
                    do jt = 0, timeseries_length - 1
                        js = jt * n_substeps
                        mQ_ts(iT, jt, iq, s) = mQ_ts(iT, jt, iq, s) + sum(mQ_aver((js+k):(js+n_substeps-1), iq, s)) * norm
                        if (carryover) then
                            mQ_ts(iT+1, jt, iq, s) = mQ_ts(iT+1, jt, iq, s) + sum(mQ_aver((js):(js+k-1), iq, s)) * norm
                        endif
                    enddo
                    do ip = 0, nP_total - 1
                        do jt = 0, timeseries_length - 1
                            if (Q_ts(jt, iq)>0) then
                                js = jt * n_substeps
                                dC_ts(jt, ip, iq, s) = dC_ts(jt, ip, iq, s) &
                                        + sum(fm_aver((js+k):(js+n_substeps-1), ip, s))/Q_ts(jt, iq) * norm * dt
                                if (carryover) then
                                    dC_ts(jt, ip, iq, s) = dC_ts(jt, ip, iq, s) &
                                            + sum(fm_aver((js):(js+k-1), ip, s))/Q_ts(jt, iq) * norm * dt
                                endif
                            endif
                        enddo
                    enddo
                enddo
            enddo
            do s = 0, numsol - 1
                do jt = 0, timeseries_length - 1
                    js = jt * n_substeps
                    mR_ts(iT, jt, s) = mR_ts(iT, jt, s) + sum(mR_aver((js+k):(js+n_substeps-1), s)) * norm
                    if (carryover) then
                        mR_ts(iT+1, jt, s) = mR_ts(iT+1, jt, s) + sum(mR_aver((js):(js+k-1), s)) * norm
                    endif
                    where ((mT_end(:, s)>0).and.(sT_end(:)>0))
                        CS_last(1:, s) = mT_end(:, s) / sT_end(:)
                    end where
                enddo
            enddo

            ! Extract substep state at timesteps
            ! age-ranked storage at the end of the timestep
            sT_ts(iT, 1:) = sT_ts(iT, 1:) + sT_end(n_substeps-1:N-1:n_substeps) / n_substeps
            ! parameter sensitivity
            do ip = 0, nP_total - 1
                ds_ts(iT, 1:, ip) = ds_ts(iT, 1:, ip) + ds_end(n_substeps-1:N-1:n_substeps, ip) / n_substeps
            enddo
            ! Age-ranked solute mass
            do s = 0, numsol - 1
                mT_ts(iT, 1:, s) = mT_ts(iT, 1:, s) + mT_end(n_substeps-1:N-1:n_substeps, s) / n_substeps
                ! parameter sensitivity
                do ip = 0, nP_total - 1
                    dm_ts(iT, 1:, ip, s) = dm_ts(iT, 1:, ip, s) + dm_end(n_substeps-1:N-1:n_substeps, ip, s) / n_substeps
                enddo
            enddo

            ! Update the cumulative instantaneous trackers
            call get_flux(h, sT_end, mT_end, ds_end, dm_end, pQ_end, mQ_end, mR_end, fs_end, fm_end, fmR_end)
            if (ik>0) then
                STcum_prev(1:N) = STcum_prev(1:N) + sT_end * h
                STcum_prev(0) = STcum_prev(0) + sT_init_ts(i_prev) * h
                call get_SAS(STcum_prev, PQcum_prev, iPj_prev, N+1)
            end if

            sT_prev = sT_end
            mT_prev = mT_end
            ds_prev = ds_end
            dm_prev = dm_end
            pQ_prev = pQ_end
            mR_prev = mR_end
            mQ_prev = mQ_end
            fs_prev = fs_end
            fm_prev = fm_end
            fmR_prev = fmR_end

            i_prev = iT

        enddo

        ! Calculate a water balance
        ! Difference of starting and ending age-ranked storage
        if (iT==0) then
            WaterBalance_ts(iT, :) = J_ts - sT_ts(iT, 1:)
        else
            WaterBalance_ts(iT, :) = sT_ts(iT-1, 0:timeseries_length-1) - sT_ts(iT, 1:timeseries_length)
        end if
        ! subtract time-averaged water fluxes
        WaterBalance_ts(iT, :) = WaterBalance_ts(iT, :) - sum(Q_ts * pQ_ts(iT, :, :), DIM=2) * dt

        ! Calculate a solute balance
        ! Difference of starting and ending age-ranked mass
        if (iT==0) then
            do s = 0, numsol - 1
                SoluteBalance_ts(iT, :, s) = C_J_ts(:, s) * J_ts - mT_ts(iT, 1:, s)
            end do
        else
            SoluteBalance_ts(iT, :, :) = mT_ts(iT-1, 0:timeseries_length-1, :) &
                    - mT_ts(iT, 1:timeseries_length, :)
        end if
        ! Subtract timestep-averaged mass fluxes
        SoluteBalance_ts(iT, :, :) = SoluteBalance_ts(iT, :, :) - sum(mQ_ts(iT, :, :, :), DIM=2) * dt
        ! Reacted mass
        SoluteBalance_ts(iT, :, :) = SoluteBalance_ts(iT, :, :) + mR_ts(iT, :, :) * dt

        ! Print some updates
        if (mod(jt, 1000).eq.1000) then
            write (tempdebugstring, *) '...Done ', char(jt), &
                    'of', char(timeseries_length)
            call f_verbose(tempdebugstring)
        endif

    enddo ! End of main loop

    call f_verbose('...Finalizing...')

    ! get the old water fraction
    P_old = 1 - sum(pQ_ts, DIM=1) * dt
    !call f_debug('P_old', (/P_old/))

    ! Estimate the outflow concentration
    do iq = 0, numflux - 1
        do s = 0, numsol - 1
            do iT = 0, max_age - 1
                !call f_debug('mQ_ts          ', mQ_ts(iT, :, iq, s))
            enddo
        enddo
    enddo
    do s = 0, numsol - 1
        do iq = 0, numflux - 1

            where (Q_ts(:,iq)>0)
                ! From the age-ranked mass
                C_Q_ts(:, iq, s) = sum(mQ_ts(:, :, iq, s), DIM=1) / Q_ts(:,iQ) * dt

                ! From the old water concentration
                C_Q_ts(:, iq, s) = C_Q_ts(:, iq, s) + alpha_ts(:, iq, s) * C_old(s) * P_old(:,iq)


            end where

            do ip = 0, nP_total - 1
                where (Q_ts(:,iq)>0)
                    dC_ts(:, ip, iq, s) = dC_ts(:, ip, iq, s) - C_old(s) * dW_ts(:, ip, iq)
                end where
            end do

            !call f_debug('C_Q_ts         ', C_Q_ts(:, iq, s))

        enddo
    enddo


    call f_verbose('...Finished...')

contains


    subroutine f_debug_blank()
        ! Prints a blank line
        if (debug) then
            print *, ''
        endif
    end subroutine f_debug_blank


    subroutine f_debug(debugstring, debugdblepr)
        ! Prints debugging information
        implicit none
        character(len = *), intent(in) :: debugstring
        real(8), dimension(:), intent(in) :: debugdblepr
        if (debug) then
            print 1, debugstring, debugdblepr
            1 format (A16, *(f16.10))
        endif
    end subroutine f_debug


    subroutine f_warning(debugstring)
        ! Prints informative information
        implicit none
        character(len = *), intent(in) :: debugstring
        if (warning) then
            print *, debugstring
        endif
    end subroutine f_warning


    subroutine f_verbose(debugstring)
        ! Prints informative information
        implicit none
        character(len = *), intent(in) :: debugstring
        if (verbose) then
            print *, debugstring
        endif
    end subroutine f_verbose


    subroutine get_SAS(STcum_in, PQcum_out, iPj_out, n_array)
        ! Call the sas function and get the transit time distribution
        integer, intent(in) :: n_array
        real(8), intent(in), dimension(0:n_array - 1) :: STcum_in
        real(8), intent(out), dimension(0:n_array - 1, 0:numflux - 1) :: PQcum_out
        integer, intent(out), dimension(0:n_array - 1, 0:nC_total - 1) :: iPj_out
        real(8), dimension(0:n_array - 1) :: PQcum_component
        ! Main lookup loop
        PQcum_out(:, :) = 0.
        do iq = 0, numflux - 1
            do ic = iC_list(iq), iC_list(iq+1) - 1
                !call f_debug('iP_list        ', (/iP_list(ic)*one8, iP_list(ic + 1)-1*one8/))
                PQcum_component(:) = 0
                do jt = 0, timeseries_length - 1
                    jk = jt * n_substeps
                    !call f_debug('getting entries', (/jk*one8, (jk+n_substeps-1)*one8, ic*one8, jt*one8/))
                    !call f_debug('SAS_lookup     ', SAS_lookup(iP_list(ic):iP_list(ic + 1)-1, jt))
                    !call f_debug('P_list         ', P_list(iP_list(ic):iP_list(ic + 1)-1, jt))
                    call lookup(&
                            SAS_lookup(iP_list(ic):iP_list(ic + 1) - 1, jt), &
                            P_list(iP_list(ic):iP_list(ic + 1) - 1, jt), &
                            STcum_in(jk:jk+n_substeps-1), &
                            PQcum_component(jk:jk+n_substeps-1), &
                            iPj_out(jk:jk+n_substeps-1, ic), &
                            iPj_prev(jk:jk+n_substeps-1, ic), &
                            nP_list(ic), n_substeps)
                end do
                PQcum_out(:N-1, iq) = PQcum_out(:N-1, iq) + weights_ss(:N-1, ic) * PQcum_component(:N-1)
                if (n_array>N) then
                    jt = timeseries_length - 1
                    !call f_debug('getting last entry', (/n_array*one8, N*one8, ic*one8, jt*one8/))
                    !call f_debug('SAS_lookup     ', SAS_lookup(iP_list(ic):iP_list(ic + 1)-1, jt))
                    !call f_debug('P_list         ', P_list(iP_list(ic):iP_list(ic + 1)-1, jt))
                    call lookup(&
                            SAS_lookup(iP_list(ic):iP_list(ic + 1)-1, jt), &
                            P_list(iP_list(ic):iP_list(ic + 1)-1, jt),  &
                            STcum_in(N:N), &
                            PQcum_component(N:N), &
                            iPj_out(N:N, ic), &
                            iPj_prev(N:N, ic), &
                            nP_list(ic), 1)
                    PQcum_out(N, iq) = PQcum_out(N, iq) + weights_ss(N-1, ic) * PQcum_component(N)
                end if
            enddo
            !call f_debug('STcum_in       ', STcum_in(:))
            !call f_debug('PQcum_out      ', PQcum_out(:, iq))
        enddo
        end subroutine get_SAS

    subroutine lookup(xa, ya, x, y, ia, i0, na, n)
        ! A simple lookup table
        implicit none
        integer, intent(in) :: na, n
        real(8), intent(in), dimension(0:na - 1) :: xa
        real(8), intent(in), dimension(0:na - 1) :: ya
        real(8), intent(in), dimension(0:n - 1) :: x
        real(8), intent(inout), dimension(0:n - 1) :: y
        integer, intent(inout), dimension(0:n - 1) :: ia
        integer, intent(inout), dimension(0:n - 1) :: i0
        integer :: i, j
        real(8) :: dif, grad
        logical :: foundit
        do j = 0, n - 1
            if (x(j).le.xa(0)) then
                y(j) = ya(0)
                ia(j) = -1
            else if (x(j).ge.xa(na - 1)) then
                y(j) = ya(na - 1)
                ia(j) = na - 1
            else
                foundit = .FALSE.
                do i = 0, na - 1
                    if (x(j).lt.xa(i)) then
                        ia(j) = i - 1
                        foundit = .TRUE.
                        exit
                    endif
                enddo
                if (.not. foundit) then
                    call f_warning('I could not find the ST value. This should never happen!!!')
                    y(j) = ya(na - 1)
                    ia(j) = na - 1
                else
                    i = ia(j)
                    dif = x(j) - xa(i)
                    grad = (ya(i + 1) - ya(i)) / (xa(i + 1) - xa(i))
                    y(j) = ya(i) + dif * grad
                endif
            endif
        enddo
    end subroutine


    subroutine get_flux(hr, sT_in, mT_in, ds_in, dm_in, pQ_out, mQ_out, mR_out, fs_out, fm_out, fmR_out)
        ! Calculates the fluxes in the given the curent state
        implicit none
        real(8), intent(in) :: hr
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1) :: sT_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: ds_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: dm_in
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR_out
        real(8), dimension(0:timeseries_length * n_substeps - 1) :: temp
        integer iq, s, ip, kk, rightend
        !call f_debug('get_flux', (/hr/))

        ! Use the SAS function lookup table to convert age-rank storage to the fraction of discharge of age T at each t

        ! First get the cumulative age-ranked storage
        if (ik==0) then
            if (hr==0) then
                STcum_start = 0
                PQcum_start = 0
                iPj_start = -1
                STcum_end = 0
                PQcum_end = 0
                iPj_end = -1
                pQ_out = 0
            else
                STcum_start = 0
                PQcum_start = 0
                iPj_start = -1
                STcum_end = 0 + sT_in * hr
                call get_SAS(STcum_end, PQcum_end, iPj_end, N)
                pQ_out = (PQcum_end - PQcum_start) / hr
            end if
        else
            STcum_start = STcum_prev(0:N-1) * (1-hr/h) + (STcum_prev(1:N) + sT_prev * h) * (hr/h)
            !PQcum_start = (PQcum_prev(0:N-1, :) * (1-hr/h) + (PQcum_prev(1:N, :) + pQ_prev * h ) * (hr/h))
            call get_SAS(STcum_start, PQcum_start, iPj_start, N)
            STcum_end = STcum_start + sT_in * h
            call get_SAS(STcum_end, PQcum_end, iPj_end, N)
            pQ_out = (PQcum_end - PQcum_start) / h
        end if

        do iq = 0, numflux - 1
            where (sT_in(:)==0)
                pQ_out(:, iq) = 0
            end where
        end do

        ! Solute mass flux accounting
        !call f_debug('getting mQ_out', (/0._8/))

        do iq = 0, numflux - 1
            !temp = Q_ss(:, iq) * pQ_out(:, iq) / sT_in(:)
            do s = 0, numsol - 1

                ! Get the mass flux out
                where (sT_in(:)>0)
                    mQ_out(:, iq, s) = mT_in(:, s) * alpha_ss(:, iq, s) * Q_ss(:, iq) * pQ_out(:, iq) / sT_in(:)

                    ! unless there is nothing in storage
                elsewhere
                    mQ_out(:, iq, s) = 0.

                end where
            enddo
        enddo

        do s = 0, numsol - 1
            ! Reaction mass accounting

            ! If there are first-order reactions, get the total mass rate
            mR_out(:, s) = k1_ss(:, s) * (C_eq_ss(:, s) * sT_in(:) - mT_in(:, s))

            !call f_debug('mQ_out         ', mQ_out(:, 0, s))
            !call f_debug('mE_out         ', mQ_out(:, 1, s))
            !call f_debug('mR_out         ', mR_out(:, s))

        enddo

        temp = sum(pQ_out*Q_ss, dim=2) / sT_in
        fs_out(:, :) = 0.
        do iq = 0, numflux - 1
            do ip = 0, nP_total - 1
                where (sT_in(:)>0)
                    fs_out(:, ip) = ds_in(:, ip) * pQ_out(:, iq) * Q_ss(:, iq) / sT_in
                elsewhere
                    fs_out(:, ip) = 0.
                end where
            end do
        end do
        do iq = 0, numflux - 1
            do ic = iC_list(iq), iC_list(iq+1) - 1
                do jt = 0, timeseries_length - 1
                    do kk = 0, n_substeps - 1
                        jk = jt * n_substeps + kk
                        ! sensitivity to point before the start
                        ip = iP_list(ic) + iPj_start(jk, ic)
                        if ((ip>=0).and.(ip<nP_list(ic)-1)) then
                            call f_debug('iP start       ', &
                                    (/ik*one8, jk*one8, ip*one8, STcum_start(jk), iPj_start(jk, ic)*one8, &
                                    STcum_end(jk), iPj_end(jk, ic)*one8, nP_list(ic)*one8-1/)*one8)
                            dS = SAS_lookup(ip+1, jt) - SAS_lookup(ip, jt)
                            dP = P_list(ip+1, jt) - P_list(ip, jt)
                            fs_out(jk, ip) = fs_out(jk, ip) &
                                    + dP / (dS*dS) * sT_in(jk) * weights_ss(jk, ic) * Q_ss(jk, iq)
                        end if
                        ! sensitivity to point after the end
                        ip = iP_list(ic) + iPj_end(jk, ic) + 1
                        if ((ip>0).and.(ip<=nP_list(ic)-1)) then
                            call f_debug('iP end         ', &
                            (/ik*one8, jk*one8, ip*one8, STcum_start(jk), iPj_start(jk, ic)*one8, &
                                    STcum_end(jk), iPj_end(jk, ic)*one8, nP_list(ic)*one8-1/)*one8)
                            dS = SAS_lookup(ip, jt) - SAS_lookup(ip-1, jt)
                            dP = P_list(ip, jt) - P_list(ip-1, jt)
                            fs_out(jk, ip) = fs_out(jk, ip) &
                                    - dP / (dS*dS) * sT_in(jk) * weights_ss(jk, ic) * Q_ss(jk, iq)
                        end if
                        ! sensitivity to point within
                        if (iPj_end(jk, ic)>iPj_start(jk, ic)) then
                            do ip = iPj_start(jk, ic)+1, iPj_end(jk, ic)
                                call f_debug('iP middle!     ', &
                                        (/ik*one8, jk*one8, ip*one8, STcum_start(jk), iPj_start(jk, ic)*one8, &
                                        STcum_end(jk), iPj_end(jk, ic)*one8, nP_list(ic)*one8-1/)*one8)
                                if (ip>0) then
                                    dSs = SAS_lookup(ip, jt) - SAS_lookup(ip-1, jt)
                                    dPs = P_list(ip, jt) - P_list(ip-1, jt)
                                else
                                    dSs = 1.
                                    dPs = 0.
                                end if
                                if (ip<nP_list(ic)-1) then
                                    dSe = SAS_lookup(ip+1, jt) - SAS_lookup(ip, jt)
                                    dPe = P_list(ip+1, jt) - P_list(ip, jt)
                                else
                                    dSe = 1.
                                    dPe = 0.
                                end if
                                fs_out(jk, ip) = fs_out(jk, ip) &
                                        - (dPe/dSe - dPs/dSs) / h * weights_ss(jk, ic) * Q_ss(jk, iq)
                            end do
                        end if
                    end do
                end do
            end do
        end do
        call f_debug_blank()
        !do ip = 0, nP_total - 1
            !call f_debug('      fs      ', fs_out(:, ip))
        !enddo
        do s = 0, numsol - 1
            !temp = sum(alpha_ss(:,:,s)*Q_ss*pQ_out, dim=2) / sT_in
            do iq = 0, numflux - 1
                do ip = 0, nP_total - 1
                    where (mT_in(:, s)>0)
                        fm_out(:, ip, s) = dm_in(:, ip, s) * alpha_ss(:,iq,s) * Q_ss(:, iq) * pQ_out(:, iq) / sT_in
                    elsewhere
                        fm_out(:, ip, s) = 0.
                    end where
                    fmR_out(:, ip, s) = 0.
                end do
            end do
            do iq = 0, numflux - 1
                do ic = iC_list(iq), iC_list(iq+1) - 1
                    do jt = 0, timeseries_length - 1
                        do kk = 0, n_substeps - 1
                            jk = jt * n_substeps + kk
                            ! sensitivity to point before the start
                            ip = iP_list(ic) + iPj_start(jk, ic)
                            if ((ip>=0).and.(ip<nP_list(ic)-1)) then
                                dS = SAS_lookup(ip+1, jt) - SAS_lookup(ip, jt)
                                dP = P_list(ip+1, jt) - P_list(ip, jt)
                                fm_out(jk, ip, s) = fm_out(jk, ip, s) &
                                        + dP / (dS*dS) * mT_in(jk, s)&
                                                * alpha_ss(jk, iq, s) * weights_ss(jk, ic) * Q_ss(jk, iq)
                                fmR_out(jk, ip, s) = fmR_out(jk, ip, s) &
                                        + k1_ss(jk, s) * (C_eq_ss(jk, s) * ds_in(jk, ip) - dm_in(jk, ip, s))
                            end if
                            ! sensitivity to point after the end
                            ip = iP_list(ic) + iPj_end(jk, ic) + 1
                            if ((ip>0).and.(ip<=nP_list(ic)-1)) then
                                dS = SAS_lookup(ip, jt) - SAS_lookup(ip-1, jt)
                                dP = P_list(ip, jt) - P_list(ip-1, jt)
                                fm_out(jk, ip, s) = fm_out(jk, ip, s) &
                                        - dP / (dS*dS) * mT_in(jk, s)&
                                                * alpha_ss(jk, iq, s) * weights_ss(jk, ic) * Q_ss(jk, iq)
                                fmR_out(jk, ip, s) = fmR_out(jk, ip, s) &
                                        + k1_ss(jk, s) * (C_eq_ss(jk, s) * ds_in(jk, ip) - dm_in(jk, ip, s))
                            end if
                            ! sensitivity to point within
                            if (iPj_end(jk, ic)>iPj_start(jk, ic)) then
                                do ip = iPj_start(jk, ic)+1, iPj_end(jk, ic)
                                    if (ip>0) then
                                        dSs = SAS_lookup(ip, jt) - SAS_lookup(ip-1, jt)
                                        dPs = P_list(ip, jt) - P_list(ip-1, jt)
                                    else
                                        dSs = 1.
                                        dPs = 0.
                                    end if
                                    if (ip<nP_list(ic)-1) then
                                        dSe = SAS_lookup(ip+1, jt) - SAS_lookup(ip, jt)
                                        dPe = P_list(ip+1, jt) - P_list(ip, jt)
                                    else
                                        dSe = 1.
                                        dPe = 0.
                                    end if
                                    fm_out(jk, ip, s) = fm_out(jk, ip, s) &
                                            - (dPe/dSe - dPs/dSs) * mT_in(jk, s) / sT_in(jk) / h &
                                                    * weights_ss(jk, ic) * Q_ss(jk, iq)
                                end do
                            end if
                        end do
                    end do
                end do
            end do
        end do


        !call f_debug('get_flux finished', (/0._8/))
        !call f_debug_blank()



    end subroutine get_flux


    subroutine new_state(hr, sT_out, mT_out, ds_out, dm_out, pQ_in, mQ_in, mR_in, fs_in, fm_in, fmR_in)
        ! Calculates the state given the fluxes

        real(8), intent(in) :: hr
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1) :: sT_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mT_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: ds_out
        real(8), intent(out), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: dm_out
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1) :: pQ_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:numflux - 1, 0:numsol - 1) :: mQ_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:numsol - 1) :: mR_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1) :: fs_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fm_in
        real(8), intent(in), dimension(0:timeseries_length * n_substeps - 1, 0:nP_total - 1, 0:numsol - 1) :: fmR_in

        !call f_debug('new_state', (/0._8/))

        ! Calculate the new age-ranked storage
        sT_out = sT_start ! Initial value
        ! Fluxes in & out
        if (ik == 0) then
            sT_out = sT_out + J_ss * hr / h
        end if
        do iq = 0, numflux - 1
            sT_out = sT_out - Q_ss(:, iq) * hr * pQ_in(:, iq)
        enddo
        !call f_debug('sT_start ns    ', sT_start(:))
        !call f_debug('sT_out ns      ', sT_out(:))
        if (ANY(sT_out<0)) then
                call f_warning('WARNING: A value of sT is negative. Try increasing the number of substeps')
        end if

        ! Print some debugging info
        do s = 0, numsol - 1
            !call f_debug('mT_start NS    ', mT_start(:, s))
            !call f_debug('mR_in NS       ', mR_in(:, s))
            do iq = 0, numflux - 1
                !call f_debug('mQ_in NS       ', mQ_in(:, iq, s))
            enddo
        enddo

        ! Calculate the new age-ranked mass
        do s = 0, numsol - 1
            ! Initial value + reaction
            mT_out(:, s) = mT_start(:, s) + mR_in(:, s) * hr
            ! Flux in
            if (ik==0) then
                mT_out(:, s) = mT_out(:, s) + J_ss(:) * C_J_ss(:, s) * (hr/h)
            end if
            ! Fluxes out
            do iq = 0, numflux - 1
                mT_out(:, s) = mT_out(:, s) - mQ_in(:, iq, s) * hr
            enddo
        enddo

        do s = 0, numsol - 1
            !call f_debug('mT_out NS      ', mT_out(:, s))
            !call f_debug('C_J_ss NS      ', (/C_J_ss(:, s)/))
        enddo
        !call f_debug('J_ss NS        ', (/J_ss(:)/))
        !call f_debug('new_state finished', (/0._8/))
        !call f_debug_blank()

        ! Calculate new parameter sensitivity
        ds_out = ds_start - fs_in * hr
        dm_out = dm_start - fm_in * hr + fmR_in * hr

    end subroutine new_state

end subroutine solve
