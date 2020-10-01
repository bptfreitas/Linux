
#include <stdio.h>

int main(){
    FILE *fd = NULL;
    int i;
    char buffer[512];

    fd = fopen("/media/VMs/teste", "w");

    for ( i = 0; i < 512; buffer[i++] = 'X' );

    for ( i = 0; i < 2 ; i++ ){
        fwrite( buffer,  sizeof(char),  512 , fd );
    }

    fclose(fd);
}

