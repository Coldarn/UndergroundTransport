#!/usr/bin/env python3

import os
import sys
import glob
import shutil
import fnmatch
import functools
import itertools
import subprocess

if len(sys.argv) < 2:
    print('ERROR: missing input directory path')
    exit(1)
if len(sys.argv) < 3:
    print('ERROR: missing port prefix name')
    exit(1)

path = sys.argv[1]
prefix = sys.argv[2]
filePattern = os.path.join('.', 'art', path, f'{prefix}-[0-9][0-9][0-9][0-9].png')
outputPath = os.path.join('.', 'graphics', path, f'{prefix}.png')

files = glob.glob(filePattern)
if not len(files):
    print('ERROR: no files found matching pattern', filePattern)
    exit(1)

print('Packing:', outputPath)
files.sort()

geometry = str(subprocess.check_output(['magick', 'identify', '-format', '%[fx:w]x%[fx:h]', files[0]]), 'utf-8')
print(f'Dimensions: {geometry}')

subprocess.check_output(['magick', 'montage', '-background', '#00000000', '-tile', '7', '-geometry', geometry, '-border', '0', *files, outputPath])
