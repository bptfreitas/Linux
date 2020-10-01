#!/usr/bin/python3
 
# Reads from file 'logins.dat' student names and then creates user logins
# Each line of 'logins.dat' must be on the format [FULL NAME]:[DEFAULT PASSWORD]:[GROUP]
# login will be [first name][last name], all in lowercase, password is DEFAULT PASSWORD or 123 if not set
# the commands will be created on the file 'insert_users.sh', which needs to be run on a linux shell

import sys

code_adduser = "\
if [[ \"`egrep '{l}' /etc/passwd`\" == \"\" ]]; then\n\
\tsudo adduser --disabled-password --gecos {l}\n\
\techo '{l}:{p}' | sudo chpasswd\n\
fi\
\n\n"

try:
	filename = sys.argv[1]
except:
	sys.stderr.write( "[ERROR] input file not set" )
	sys.exit(-1)

NAME_INDEX = 0
PASSWORD_INDEX = 1
GROUP_INDEX = 2

try:
	with open(filename,'r') as logins_list:

		# read and discard first header line
		header = logins_list.readline()

		# list of all students
		all_students = []

		# dictionary for grouping students
		all_groups = {}

		# processing file
		line_nr = 1
		for line in logins_list:
			data = line.split(':')

			name = data[ NAME_INDEX ]

			sys.stdout.write("\nAdding '" + str(name) + "' to the list ...")

			try:
				password = data[ PASSWORD_INDEX ]

				if len( password.strip() ) == 0:
					password = '123'
					
			except IndexError:
				sys.stderr.write("[ERROR] Invalid index reading password value at line" + str(line_nr) )
				sys.exit(-1)

			try:
				group = int( data[ GROUP_INDEX ] )

			except IndexError:
				sys.stderr.write( "\n[ERROR] Invalid index reading 'group' value at line" + str(line_nr) )
				sys.exit(-1)
			except ValueError:
				sys.stderr.write( "\nNOTICE: No group defined for '" + str(name) + "'" )
				

			# adding student tuple and group
			all_students.append(  ( name, password, group )  )

			line_nr += 1
except IOError:
	sys.stderr.write( '\n[ERROR] cant open file' )
	sys.exit(-1)

####################################################
# Creating script to insert users on the UI server #
####################################################
script_InsertUsers = open( 'create_users-GFX_server.sh' , 'w' )
script_InsertUsers.write( "#!/bin/bash\n" )

for student in all_students:

	fullname = student[ NAME_INDEX ]
	name_parts = fullname.split(' ')
	password = student[ PASSWORD_INDEX ]

	if len(name_parts) < 2:
		sys.stderr.write("\n[NOTICE] Can't create login for '" + fullname + "'" )
	else:
		login = ( name_parts[ 0 ].strip() + name_parts[ -1 ].strip() ).lower()

		sys.stdout.write( "\nCreating login '" + login + "'" )

		script_InsertUsers.write( code_adduser.format( l = login , p = password )  )

script_InsertUsers.close()

#########################################
# Creating script to create student VMs #
#########################################
script_CreateVMs = open( 'create_VMs.sh' , 'w' )
script_CreateVMs.write( "#!/bin/bash\n" )

	
script_CreateVMs.close()


sys.stdout.write('\n')