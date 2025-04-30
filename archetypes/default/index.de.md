+++
title = "{{ replace .Name "-" " " | title }}"
date = '{{ .Date }}'
description = "{{ replace .Name "-" " " | title }}"
summary = "{{ replace .Name "-" " " | title }}"
# Categories are generally used for broader, top-level topics.
categories = [
 'alkohol',
 'getränke',
 'lebensmittel',
 'mitarbeiter',
 'unternehmensintern',
 'rechtliches',
 'ankündigung',
 'produkt',
]
# Tags are used for more specific, detailed topics.
tags = [
 'bier',
 'schokolade',
 'milchshake',
 'chips',
 'rum',
 'bedingungen',
 'bewerben',
]
# Remove this to publish.
draft = true
+++
