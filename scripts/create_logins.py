#!/usr/bin/python3
 
# Reads from file 'logins.dat' student names and then creates user logins
# Each line of 'logins.dat' must be on the format [FULL NAME]:[DEFAULT PASSWORD]
# login will be [first name][last name], all in lowercase, password is DEFAULT PASSWORD or 123 if not set
# the commands will be created on the file 'insert_users.sh', which needs to be run on a linux shell

output = open('insert_users.sh','w')

output.write("#!/bin/bash\n");

with open('logins.dat','r') as logins_list:

	for line in logins_list:
		data = line.split(':')

		name = data[0].split(' ')
		password = data[1]

		login = ( name[0].strip() + name[len(name)-1].strip() ).lower()

		if len( password.strip() ) == 0:
			password = '123'

		print('Creating "' + login + '"...')

		output.write("sudo adduser --disabled-password --gecos '' " + login + "\n");

		output.write("echo '"+login+":" + password + "' | sudo chpasswd\n");

	output.close()
