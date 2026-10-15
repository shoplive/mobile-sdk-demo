import sys, re, xml.etree.ElementTree as ET
res, out = sys.argv[1], sys.argv[2]
def load(path):
    d={}
    for e in ET.parse(path).getroot().findall('string'):
        t=''.join(e.itertext())
        t=t.replace("\\'", "'").replace('\\"','"').replace('\\n','\n')
        i=[0]
        def seq(m):
            r='{%d}'%i[0]; i[0]+=1; return r
        t=re.sub(r'%(\d)\$[sd]', lambda m:'{%d}'%(int(m.group(1))-1), t)
        t=re.sub(r'%[sd]', seq, t)
        d[e.get('name')]=t
    return d
locs={'en':load(f'{res}/values/strings.xml'),'ko':load(f'{res}/values-ko/strings.xml'),'ja':load(f'{res}/values-ja/strings.xml')}
def lit(s): return "'"+s.replace('\\','\\\\').replace("'","\\'").replace('$','\\$').replace('\n','\\n')+"'"
with open(out,'w') as f:
    f.write('// GENERATED from Android/app/src/main/res/values*/strings.xml — do not edit by hand.\n')
    f.write('// Flutter-specific wording lives in demo_strings.dart (flutterOverrides), which wins.\n')
    f.write('// Regenerate: python3 Flutter/tool/strings_gen.py Android/app/src/main/res Flutter/lib/demo/l10n/generated_strings.dart\n\n')
    f.write('const Map<String, Map<String, String>> generatedStrings = {\n')
    for k,d in locs.items():
        f.write(f"  '{k}': {{\n")
        for n,v in d.items(): f.write(f"    '{n}': {lit(v)},\n")
        f.write('  },\n')
    f.write('};\n')
missing={k:[n for n in locs['en'] if n not in d] for k,d in locs.items()}
print({k:len(v) for k,v in locs.items()}, {k:v for k,v in missing.items() if v})
