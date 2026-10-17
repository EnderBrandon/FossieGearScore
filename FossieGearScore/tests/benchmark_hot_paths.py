"""Repeat deterministic Lua 5.1 UI fixtures; timings are not in-client FPS claims.

Run from any directory with the same lupa dependency as run_tests.py.
Reports native metadata reads, inventory reads and item calculations as well
as elapsed Lua CPU time. No live client or account is accessed.
"""
import argparse
import json
import statistics
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--addon-root',type=Path,default=Path(__file__).resolve().parents[1])
parser.add_argument('--samples',type=int,default=5)
args=parser.parse_args()
if args.samples<1: parser.error('--samples must be positive')
os.chdir(args.addon_root)
source = Path('tests/test_inspection_panel.lua').read_text()
source = source.replace('local calculate=NS.CalculateItemScore', '''local metadataReads=0
for _,key in ipairs({"GetItemInfo", "GetItemInfoInstant"}) do
    local original=C_Item[key]
    C_Item[key]=function(...) metadataReads=metadataReads+1; return original(...) end
end
local calculate=NS.CalculateItemScore''', 1)
source = source.replace('do\n    local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests', '''do
    local who=NS.CaptureInspectionSelection("target")
    local reads,scans,calculations=metadataReads,inventoryReads,scoreCalls
    collectgarbage("collect")
    local started=os.clock()
    for i=1,2000 do NS.BuildInspectionPanelData(who) end
    benchmarkReport("menu projections",2000,os.clock()-started,metadataReads-reads,inventoryReads-scans,scoreCalls-calculations)
    reads,scans,calculations=metadataReads,inventoryReads,scoreCalls
    started=os.clock()
    for i=1,100 do fire("ADDON_LOADED","BenchmarkOtherAddon"); advance(0) end
    benchmarkReport("unrelated addon loads",100,os.clock()-started,metadataReads-reads,inventoryReads-scans,scoreCalls-calculations)
end
do
    local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests''', 1)
source = source.replace('    local profile=NS.ClassifyTalents("DRUID",{0,0,31},30,"NightElf")', '''    do
        local reads,scans,calculations=metadataReads,inventoryReads,scoreCalls
        collectgarbage("collect")
        local started=os.clock()
        for i=1,1000 do
            local clone={}; for key,value in pairs(rec) do clone[key]=value end
            NS.BuildGearAssessment(30,clone,true)
        end
        benchmarkReport("unchanged spec snapshots",1000,os.clock()-started,metadataReads-reads,inventoryReads-scans,scoreCalls-calculations)
    end
    local profile=NS.ClassifyTalents("DRUID",{0,0,31},30,"NightElf")''', 1)
samples=[]
for _ in range(args.samples):
    rows=[]
    def report(name, iterations, seconds, metadata, inventory, calculations):
        rows.append(dict(case=name, iterations=iterations, cpu_seconds=seconds,
                         metadata_reads=metadata, inventory_reads=inventory, item_calculations=calculations))
    lua=LuaRuntime()
    lua.globals().benchmarkReport=report
    lua.globals().print=lambda *values: None
    lua.execute(source)
    assert len(rows)==3, 'Benchmark insertion points changed; update the fixture hooks.'
    samples.append(rows)
results=[]
for index,first in enumerate(samples[0]):
    result=dict(first)
    for key in ('case','iterations','metadata_reads','inventory_reads','item_calculations'):
        assert all(run[index][key]==first[key] for run in samples), f'Unstable {key} counts'
    result['cpu_seconds']=round(statistics.median(run[index]['cpu_seconds'] for run in samples),6)
    result['samples']=args.samples
    results.append(result)
print(json.dumps(results,indent=2))
