#!/usr/bin/env python3

import json
import os
import sys
import shutil
import fnmatch
import functools
import itertools
import subprocess

# define additional patterns for files here that are not in the .gitignore file and should be omitted from the zipped mod
additionalIgnorePatterns = ['*.py', '*.exe', '.git', '.gitignore', '*.mp4', '.vscode', 'art']

# read all git ignore patterns that apply to a given git repo root directory
def readAllGitIgnorePatterns(dir):
  # the repo's local .gitignore file
  patterns = readGitIgnorePatterns(os.path.join(dir, '.gitignore'))

  # the user's global excludesfile, most commonly ~/.gitignore
  try:
    gitExcludesFile = os.path.expanduser(
      subprocess.check_output([
        'git',
        '--git-dir',
        os.path.join(dir, '.git'),
        'config',
        'core.excludesfile'
      ]).rstrip().decode("utf-8")
    )
    patterns |= readGitIgnorePatterns(gitExcludesFile)
  except subprocess.CalledProcessError:
    pass

  return patterns

# reads non-commented ignore patterns from a single .gitignore file
def readGitIgnorePatterns(gitIgnoreFilename):
  patterns = set()

  if os.path.isfile(gitIgnoreFilename):
    with open(gitIgnoreFilename) as gitIgnoreFile:
      for line in gitIgnoreFile:
        if not line.startswith('#'):
          if line.endswith('\n'):
            patterns.add(line[:-1])
          else:
            patterns.add(line)

  return patterns

# taken from http://stackoverflow.com/questions/5351766/use-fnmatch-filter-to-filter-files-by-more-than-one-possible-file-extension/25413436#25413436
# modified for ignoreFunction use
def find_files(dir_path: str=None, patterns: [str]=None) -> [str]:
    path = dir_path or "."
    path_patterns = patterns or []

    file_names = os.listdir(path)
    filter_partial = functools.partial(fnmatch.filter, file_names)

    for file_name in itertools.chain(*map(filter_partial, path_patterns)):
        yield file_name

# function to be passed to copytree, see https://docs.python.org/2/library/shutil.html#shutil.copytree
def ignoreFunction(directory, files):
  #TODO curry this function to include modDir, rather than using global variable
  ignorePatterns = readAllGitIgnorePatterns(modDir)
  ignorePatterns = list(ignorePatterns)

  for additionalPattern in additionalIgnorePatterns:
    ignorePatterns.append(additionalPattern)

  ignoredFiles = [file for file in find_files(directory, ignorePatterns)]

  return ignoredFiles

## script start
# optionally read target directory from first command line parameter
if len(sys.argv) == 2:
  modDir = sys.argv[1]
else:
  modDir = '.'

if os.path.isdir(modDir):
  modInfoJson = os.path.join(modDir, 'info.json')

  if os.path.isfile(modInfoJson):
    with open(modInfoJson) as infoFile:
      modInfo = json.load(infoFile)

    if modInfo is not None:
      modName = modInfo['name']
      modVersion = modInfo['version']

      modFileName = modName + '_' + modVersion
      tempDir = os.path.join ('.', 'tmp')
      tempModDir = os.path.join(tempDir, modFileName)

      shutil.copytree(modDir, tempModDir, ignore=ignoreFunction)

      if os.path.isfile(modFileName + '.zip'):
        os.remove(modFileName + '.zip')

      shutil.make_archive(modFileName, 'zip', tempDir)
      shutil.rmtree(tempDir)
  else:
    print('"%s" does not contain a "info.json" file.' %modDir) 
else:
  print('"%s" is not a valid directory.' % modDir)
