#!/usr/bin/python3
 
# Reads from file 'lista_alunos.dat' student names and then creates user logins
# login will be [first name][last name], all in lowercase, password is 123
# the commands will be created on the file 'insert_users.sh', which needs to be run on a linux shell

output = open('insert_users.sh','w')

output.write("#!/bin/bash\n");

with open('lista_alunos.dat','r') as alunos:

	for line in alunos:
		data = line.split(' ')

		login = ( data[0].strip() + data[len(data)-1].strip() ).lower()

		print('Creating "' + login + '"...')

		output.write("sudo adduser --disabled-password --gecos '' " + login + "\n");

		output.write("echo '"+login+":123' | sudo chpasswd\n");

	output.close()
