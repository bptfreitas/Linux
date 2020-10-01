void *Produtor(void* thread_data_p){
	thread_data_t* thread_data=((thread_data_t*)thread_data_p);

    data_t *fila=thread_data->shared_data;
    int thread_id=thread_data->thread_id;

    int n=0;
    while(1){
        while (fila->size==SIZE);

        int produzido=produz_item();

        fila->data[fila->in%SIZE]=produzido;

        fila->size++;		
        fila->in++;       
    }
}
