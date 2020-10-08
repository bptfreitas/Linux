#!/usr/bin/python3
 
# Reads from file 'logins.dat' student names and then creates user logins
# Each line of 'logins.dat' must be on the format [FULL NAME]:[DEFAULT PASSWORD]:[GROUP]
# login will be [first name][last name], all in lowercase, password is DEFAULT PASSWORD or 123 if not set
# the commands will be created on the file 'insert_users.sh', which needs to be run on a linux shell

import sys

code_adduser = "\
if [[ \"`egrep '{l}' /etc/passwd`\" == \"\" ]]; then\n\
\tsudo adduser --disabled-password --gecos {l}\n\
\techo '{l}:{p}' | sudo chpasswd \n\
fi\
\n\n"

code_adduser_proxmox = "\n\
echo \"Creating VM {vm_id} for user '{l}'\" >> ${{LOG}} \n\
pvum useradd {l} --password {p}\n\
qm clone 9004 {vm_id} \n\
if [[ $? -eq 0 ]]; then \n\
\tfor i in `seq ${{total_nodes}}`; do \n\
\t\tcurrent_node=$(( (current_node + 1) % total_nodes ))\n\
\t\techo \"Migrating VM {vm_id} to node ${{nodes[$current_node]}}\" \n\
\t\tqm migrate {vm_id} ${{nodes[$current_node]}} \n\
\t\tif [[ $? -eq 0 ]]; then \n\
\t\t\techo \"Migration concluded. Changing permissions to VM\" >> ${{LOG}} \n\
\t\t\tpveum aclmod /vms/{vm_id} -user {l}@pve -role AlunoCefet \n\
\t\t\tbreak \n\
\t\telse\n\
\t\t\tif [[ $i -eq ${{total_nodes}} ]]; then \n\
\t\t\t\techo \"Migration to all nodes failed\" >> ${{LOG}} \n\
\t\t\telse \n\
\t\t\t\techo \"Migration ${{i}}/${{total_nodes}} failed. Trying next node.\" >> ${{LOG}}\n\
\t\t\tfi\n\
\t\tfi\n\
\tdone \n\
else \n\
\techo \"Error cloning VM 9004 to {vm_id}\" >> ${{LOG}}\n\
fi\n\
\n\n"

try:
	filename = sys.argv[1]
except:
	sys.stderr.write( "[ERROR] input file not set" )
	sys.exit(-1)

# column indexes
NAME_INDEX = 0
PASSWORD_INDEX = 1
GROUP_INDEX = 2
VM_PREFIX_INDEX = 3

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
		machine_counter = {}
		machine_counter[ 99 ] = 1 # default prefix
		added_users = []
		for line in logins_list:
			data = line.split(':')
			
			try:								
				name = data[ NAME_INDEX ].strip()
				sys.stdout.write("\nProcessing '" + str(name) + "' ...")
			except IndexError:
				sys.stderr.write("[ERROR] Invalid index reading 'name' value at line" + str(line_nr) )
				sys.exit(-1)

			if name in added_users:
				sys.stderr.write("[NOTICE] User '" + name + "' already added at line " + str(line_nr) )
				continue

			try:
				password = data[ PASSWORD_INDEX ]

				if len( password.strip() ) == 0:
					password = '123'
					
			except IndexError:
				sys.stderr.write("[ERROR] Invalid index reading 'password' value at line" + str(line_nr) )
				sys.exit(-1)
			try:
				group = int( data[ GROUP_INDEX ] )

			except IndexError:
				sys.stderr.write( "\n[ERROR] Invalid index reading 'group' value at line" + str(line_nr) )
				sys.exit(-1)
			except ValueError:
				group = -1
				sys.stderr.write( "\n[NOTICE] No group defined for '" + str(name) + "'" )

			try:
				vm_prefix = int( data[ VM_PREFIX_INDEX ] )
				
			except IndexError:
				sys.stderr.write( "\n[ERROR] Invalid index reading 'machine_prefix' value at line " + str(line_nr) + '\n')
				sys.exit(-1)
			except ValueError:
				vm_prefix = 99
				sys.stderr.write( "\n[NOTICE] No 'machine_prefix' defined for '" + str(name) + "'" )
				
			# adding student tuple and group
			student_info = { 'name' : name, 
				'password' : password, 
				'group' : group, 
				'vm_prefix' : vm_prefix }

			all_students.append( student_info )

			added_users.append( name )

			sys.stdout.write( '\n' + str( student_info ) )

			line_nr += 1
except IOError:
	sys.stderr.write( "\n[ERROR] no input file\n" )
	sys.exit(-1)

####################################################
# Creating script to insert users on the UI server #
####################################################
preamble = "#!/usr/bin/python3 \n\
\n\
LOG=addusers.log\n\
> ${{LOG}} \n\
\n\
nodes[0]=proxmox \n\
nodes[1]=proxmox2 \n\
nodes[2]=proxmox3 \n\
nodes[3]=proxmox4 \n\
nodes[4]=proxmox5 \n\
nodes[5]=proxmox6 \n\
nodes[6]=proxmox7 \n\
nodes[7]=proxmox8 \n\
\n\
total_nodes=${#nodes[@]} \n\
current_node=0 \n\
\n\
"

script_InsertUsers = open( 'TEST-create_users.sh' , 'w' )
script_InsertUsers.write( preamble )

vm_counter = { }
for student in all_students:

	fullname = student[ 'name' ]
	name_parts = fullname.split(' ')
	password = student[ 'password' ]
	group = student[ 'group' ]
	vm_prefix = student[ 'vm_prefix' ]

	if vm_prefix not in vm_counter.keys():
		vm_counter[ vm_prefix ] = 1
	else:
		vm_counter[ vm_prefix ] += 1

	vm_id = '{vm_prefix:0>2d}{vm_index:0>4d}'.format( 
		vm_prefix = vm_prefix, 
		vm_index = vm_counter[ vm_prefix ] )

	if len(name_parts) < 2:
		sys.stderr.write("\n[NOTICE] Can't create login for '" + fullname + "'" )
	else:
		login = ( name_parts[ 0 ].strip() + name_parts[ -1 ].strip() ).lower()

		sys.stdout.write( "\nCreating login '" + login + "'" )

		script_InsertUsers.write( 
			code_adduser_proxmox.format( l = login , p = password, vm_id = vm_id )  )

sys.stdout.write( "\n" )

script_InsertUsers.close()