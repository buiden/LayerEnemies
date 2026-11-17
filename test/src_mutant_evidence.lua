-- Run real narrow mutant suites twice, not synthesized reports.
local h=...
for _,name in ipairs({"source","presence"}) do
    h.test("Stack: "..name.." mutant evidence rerun is byte and mtime stable",function()
        local command="python3 -B test/mutant_evidence_test.py StableEvidenceTest.test_"..name..
            "_rerun_is_byte_and_mtime_stable 2>&1; printf '\\nRUNNER_RC=%s\\n' \"$?\""
        local p=assert(io.popen(command)); local result=p:read("*a"); p:close()
        -- Keep the traceback/assertion, not unittest's nondeterministic duration.
        local diagnostic=result:gsub("Ran (%d+ tests?) in [%d%.]+s","Ran %1")
        h.yes(result:find("RUNNER_RC=0",1,true),(diagnostic:gsub("[\r\n]+"," | ")))
        h.yes(result:find("Ran 1 test",1,true),"actual evidence regression collected")
    end)
end
