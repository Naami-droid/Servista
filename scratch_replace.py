import sys

with open('f:/Karobar_AI/mobile/lib/features/customer/chat_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

target = 'Text("${p[\'rating\']} ⭐ | PKR ${p[\'base_rate\']}"),'
replacement = 'Text("${p[\'rating\']} ⭐ | PKR ${p[\'base_rate\']}"),\n                            Text("${_pendingProviders![i][\'distance_km\']} km away", style: const TextStyle(color: Colors.grey, fontSize: 12)),'

if target in code:
    code = code.replace(target, replacement)
    with open('f:/Karobar_AI/mobile/lib/features/customer/chat_screen.dart', 'w', encoding='utf-8') as f:
        f.write(code)
    print('Replaced')
else:
    print('Not found')
