#!/usr/bin/python3

output = open('comandos.sh','w')

output.write("#!/bin/bash\n");

with open('lista_alunos.dat','r') as alunos:

	for line in alunos:
		data = line.split(' ')

		login = ( data[0].strip() + data[len(data)-1].strip() ).lower()

		print(login)

		output.write("sudo adduser --disabled-password --gecos '' " + login + "\n");

		output.write("echo '"+login+":123' | sudo chpasswd\n");

	output.close()
