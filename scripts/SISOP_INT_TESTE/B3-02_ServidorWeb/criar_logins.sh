#!/bin/bash


awk '{ print $1$NF }' lista_alunos.dat > logins.dat

echo '#!/bin/bash' > comandos.sh

for login in $( cat logins.dat ); do

    login="`echo ""${login}"" | tr '[:upper:]' '[:lower:]' | sed 's/[[:blank:]]//g'`"

    echo "${login}"

    echo "adduser --force-badname $login" >> comandos.sh

    break
done


