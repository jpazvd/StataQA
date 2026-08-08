*! version 2.1.0  06aug2026
* stqa_endtest: Close a test block
* Description: Emits the PASS: verdict token for a clean block, books a failure
*              already reported by an assertion, or stays silent for a block that
*              was skipped or targeted out.  Always clears the block state,
*              including the legacy whole-file skip flags.
* Options: none
* Author: Joao Pedro Azevedo (UNICEF)
* License: MIT
program define stqa_endtest
    version 14.0

    if `"`0'"' != "" {
        di as error "stqa_endtest takes no arguments"
        exit 198
    }

    * Trace is turned off first so the verdict line itself is not echoed.
    * Note that Stata restores -set trace- to its entry value when a program
    * exits, so this call is a safety net inside stqa_endtest only; tracing
    * switched on by a caller further up the stack (stqa_run) is unaffected.
    if "$stqa_verbose" == "1" {
        set trace off
    }

    local id `"$stqa_test_id"'
    local nm `"$stqa_test_name"'

    * ------------------------------------------------------------------
    * No open block: never emit a verdict with an empty id (that would be a
    * phantom PASS in the log).  Warn and leave the counters untouched.
    * ------------------------------------------------------------------
    if `"`id'"' == "" & `"`nm'"' == "" {
        di as error "stqa_endtest: no open test block - stqa_test is missing"
        exit 0
    }

    if "$stqa_skip_block" == "1" {
        * Skipped block.  Either targeted out (nothing was reported, and
        * nothing should be) or skipped by stqa_skip, which already emitted
        * the SKIP: token and incremented $stqa_n_skip.  Emit nothing.
    }
    else if "$stqa_block_failed" == "1" {
        * The FAIL: token was already emitted by the failing assertion.
        local nfail `"$stqa_n_fail"'
        if `"`nfail'"' == "" local nfail 0
        global stqa_n_fail = `nfail' + 1

        local fids `"$stqa_failed_ids"'
        if `"`fids'"' == "" {
            local fids `"`id'"'
        }
        else {
            local fids `"`fids' `id'"'
        }
        global stqa_failed_ids `"`fids'"'
    }
    else {
        di as result `"PASS: `id' `nm'"'
        local npass `"$stqa_n_pass"'
        if `"`npass'"' == "" local npass 0
        global stqa_n_pass = `npass' + 1
    }

    global stqa_test_id ""
    global stqa_test_name ""
    global stqa_block_failed ""
    global stqa_skip_block ""

    * ------------------------------------------------------------------
    * The legacy whole-file skip flags are block state too, and clearing
    * them here is what closes a reproduced silent false pass ACROSS FILES.
    * stqa_skip set $stqa_SKIP_FLAG and nothing ever unset it, so once any
    * block in any file skipped, every later file that opens with the
    * documented guard line
    *
    *     if "$stqa_SKIP_FLAG" == "1" exit
    *
    * exited at that line without running a single check.  The suite then
    * reported far fewer checks than it has and still read green, because a
    * file that runs nothing fails nothing.  Nothing in the package reads
    * these two globals after a test file has returned, so there is no
    * reader left to break by clearing them at the close of the block that
    * set them.
    * ------------------------------------------------------------------
    global stqa_SKIP_FLAG ""
    global stqa_SKIP_MSG ""
end
