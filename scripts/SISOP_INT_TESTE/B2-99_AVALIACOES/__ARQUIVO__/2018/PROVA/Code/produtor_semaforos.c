void *Produtor(void* thread_data_p){
	thread_data_t* thread_data=((thread_data_t*)thread_data_p);

    data_t *fila=thread_data->shared_data;
    int thread_id=thread_data->thread_id;

    while(1){
        sem_wait(&fila->is_full);      

        int produzido=produz_item();

        fila->data[fila->in%SIZE]=produzido;

        fila->in++;        

        sem_post(&fila->is_empty);
    }
}
