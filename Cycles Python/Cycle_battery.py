import serial
import time

from datetime import datetime
def leer_datos_serial_y_escribir_en_archivo_y_enviar_a_arduino(puerto_lectura, puerto_escritura, archivo):
    try:
        puerto_lectura.flush()
        puerto_lectura.write(b'VAL?\r\n')
        time.sleep(0.01)
        if puerto_lectura.in_waiting > 0:
            data3 = puerto_lectura.readline().decode('utf-8').strip()
            data = puerto_lectura.readline().decode('utf-8').strip()
            #data2 = puerto_lectura.readline().decode('utf-8').strip()
            #data4 = puerto_lectura.readline().decode('utf-8').strip()

            puerto_lectura.flush()
            #print(data)
            # print("si1")
            # Leer datos del puerto COM51

        #print(data3)
        #print(data)
        # # Escribir los datos en el archivo
        # file.write(user_input + ',' + data + ',' + data2 + ',' + datetime.now().strftime('%Y-%m-%d %H:%M:%S:%f') + '\n')
        # file.flush()  # Forzar la escritura inmediata en el archivo
        # ser_escritura.write(data_tot.encode('utf-8') + b'\n')
        # time.sleep(0.01)
        # ser_escritura.flush()

        if puerto_lectura.in_waiting <= 0:
            print("no me meto en el if")

        puerto_escritura.write(data.encode('utf-8') + b'\n')
                                    # vdc_adc_data = data.split(",")  # Dividir la cadena en valores VDC y ADC
        # ser_escritura.write(",".join(vdc_adc_data).encode('utf-8') + b'\n')
        time.sleep(0.01)
        if puerto_escritura.in_waiting > 0:
            value = puerto_escritura.readline().decode('utf-8').strip()
            puerto_escritura.flush();
            # print(datetime.now().strftime('%Y-%m-%d %H:%M:%S:%f'))
            print(value)
            file.write(value + ','+ datetime.now().strftime('%Y-%m-%d %H:%M:%S:%f') + '\n')
            file.flush()  # Forzar la escritura inmediata en el archivo
        time.sleep(0.01)
        # print("iter")
                            

    except serial.SerialException as e:
        print("Error de conexión serial:", e)
        escribir=0

if __name__ == "__main__":
    puerto_lectura = 'COM5'
    puerto_escritura = 'COM4'

    archivo = 'datos_serial_' + datetime.now().strftime("%m_%d_%Y__%H__%M__%S") +'.txt'
    # Inicializar conexión serie con el COM
    puerto_lectura = serial.Serial(puerto_lectura, 9600, 8, 'N', 1)
    print("Conexión serial de lectura establecida con éxito.")

    puerto_lectura.write(b'ADC\r\n')
    puerto_lectura.write(b'RANGE 4\r\n')
    puerto_lectura.write(b'RATE S\r\n')
    puerto_lectura.write(b'VDC2\r\n')


    # Inicializar conexión serie con el COM50 (Arduino)
    puerto_escritura = serial.Serial(puerto_escritura, 9600)
    print("Conexión serial de escritura establecida con éxito.")
    echo=False
    puerto_lectura.write(b'ATE0\r\n' if not echo else b'ATL1\r\n')
    puerto_lectura.flush()
    puerto_escritura.flush();
    # Abrir el archivo en modo de escritura
    with open(archivo, 'w') as file:
        print('Open file')
        T = time.time()            
        while True:
            if time.time()-T>1:
                T=time.time()
                #print(T)
                leer_datos_serial_y_escribir_en_archivo_y_enviar_a_arduino(puerto_lectura, puerto_escritura, archivo)

