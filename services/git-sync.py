#!/usr/bin/python

import subprocess
import os
import argparse
import sys
import re
import socket

# git push origin master
# git 

debug=False

def git_config_credentials(repository):
	url = repository['url']
	project = repository['project']
	dstdir = repository['dstdir']
	
	projectdir=dstdir + '/' + project

	cwd = os.getcwd()
	os.chdir(projectdir)

	print "Starting credentials setup ... "

	cmd = ['git','config','credential.helper','store']
	subprocess.call(cmd,stdout=subprocess.PIPE)

	cmd = ['git','config','--global','push.default','matching']
	subprocess.call(cmd,stdout=subprocess.PIPE)

	print "Pushing dummy file (should ask for a password)"
	cmd = ['git','push']
	subprocess.call(cmd,stdout=subprocess.PIPE)

	os.chdir(cwd)

# clones a repository
def git_clone(repository):
	url = repository['url']
	project = repository['project']
	dstdir = repository['dstdir']
	
	giturl = url + '/' + project + '.git'

	print "CLONE: " + project + " => " + dstdir

	cwd = os.getcwd()

	try:
		os.makedirs(dstdir)
	except:
		pass

	try:
		os.chdir(dstdir)
	except:
		print dstdir + " doesnt exist - aborting"
		sys.exit(-1)
	
	if project not in os.listdir(dstdir):
		cmd = ['git','clone',giturl]
		subprocess.call(cmd,stdout=subprocess.PIPE)
	else:
		print("Skipping clone of " + project + "\n")

	os.chdir(cwd)

# commits all changes on a branch
def git_commit(repository):
	url = repository['url']
	project = repository['project']
	dstdir = repository['dstdir']

	projectdir = dstdir + '/' + project
	hostname = socket.gethostname()
	
	giturl = url + '/' + project + '.git'

	cwd = os.getcwd()
	os.chdir(projectdir)

	output=subprocess.check_output(['git','status','-s'])

	print "Commiting changes on project " + project

	for line in output.split("\n"):
		line = line.strip()

		if len(line)<=0:
			break

		status,filename = line.split(" ")

		print status, " ", filename

		cwd = os.getcwd()		

		if status=="??":
			message="Adding " + filename + "..."
			cmd = ['git','add',filename]
			output=subprocess.check_output(cmd)

		os.chdir(cwd)

	message="Daily commit ... "
	cmd = ['git','commit','-a','-m',message]
	try:
		output=subprocess.check_output(cmd)
	except: 
		pass

	os.chdir(cwd)

# pushes a branch to remote
def git_push(repository):
	url = repository['url']
	project = repository['project']
	dstdir = repository['dstdir']

	gitdir = dstdir + '/' + project

	cmd = ['git','push']

	try:
		output=subprocess.check_output(cmd)
	except: 
		pass


parser = argparse.ArgumentParser(description='Syncs github at login and logoff')
parser.add_argument('--url', type=str, nargs='?',
                    help='base github url')

parser.add_argument('--actions','-a', type=str, nargs='+',
                    help='git actions to execute (config_credentials|clone|commit|push)')

parser.add_argument('--file','-f', type=argparse.FileType('r'), nargs='?',default='/root/.git-repositories',
                    help='file with repositories descriptions')

args=vars(parser.parse_args())

all_actions=args['actions']

print all_actions

repositories=[]
if debug:
	repositories = [ 
		{
		  'url' : 'https://github.com/bptfreitas' ,
		  'project' : 'PlanejadorHorarios' ,
		  'dstdir' : '/home/bruno'
		}
	]
else:
	for line in args['file']:
		repository=line.split(';')
		repositories.append(
			{
				'url': repository[0].strip(),
				'project': repository[1].strip(),
				'dstdir': repository[2].strip(),
			}
		)
	args['file'].close()

for repo in repositories:
	for action in all_actions:
		if action=='config_credentials':
			git_config_credentials(repo)
		elif action=='clone':
			git_clone(repo)
		elif action=='commit':
			git_commit(repo)
		elif action=='push':
			git_push(repo)
