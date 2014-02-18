//
//  main.cpp
//  HttpSoketFromiPhone
//
//  Created by shouian on 13/5/12.
//  Copyright (c) 2013年 Sail. All rights reserved.
//

// Socket
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
// Base h file
#include <iostream>
#include <string.h>
#include <pthread.h>
// Handle error
#include <errno.h>
// OpenCV
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>

using namespace std;
using namespace cv;

Mat img, img1;
int is_data_ready = 0;
int listenSock, connectSock;
int listenPort = 9899; // We define it

pthread_mutex_t mutex1 = PTHREAD_MUTEX_INITIALIZER;

// Define streaming function
void* streamServer(void* arg);
void  quit(string msg, int retval);
unsigned long unpacki32(char *buf);

int main(int argc, const char * argv[])
{
    pthread_t thread_server;
    int width, height, key;
    
    width = 640;
    height = 480;
    
    img = Mat(width, height, CV_8UC1);
    
    // Run another thread
    if (pthread_create(&thread_server, NULL, streamServer, NULL)) {
        quit("thread create failed.", 1);
    }
    
    namedWindow("stream_server", CV_WINDOW_AUTOSIZE);
    
    while (key != 'q') {
        pthread_mutex_lock(&mutex1);
        if (is_data_ready) {
            imshow("Stream Server", img);
            is_data_ready = 0;
        }
        pthread_mutex_unlock(&mutex1);
        key = waitKey(10);
    }
    
    if (pthread_cancel(thread_server)) {
        quit("pthread_cancel failed.", 1);
    }
    
    destroyWindow("stream_server");
    quit("NULL", 0);
    
    return 0;
}

// Streaming from Image client
void* streamServer(void* arg)
{
    struct sockaddr_in serverAddr, clientAddr;
    socklen_t clientAddrLen = sizeof(clientAddr);
    
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL); // ASYNCHRONOUS
    
    if ((listenSock = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
        quit("socket() failed. ", 1);
    }
    
    serverAddr.sin_family = PF_INET;
    serverAddr.sin_addr.s_addr = htonl(INADDR_ANY);
    serverAddr.sin_port = htons(listenPort);
    
    // Bind the port
    if (bind(listenSock, (sockaddr *)&serverAddr, sizeof(serverAddr)) == -1) {
        quit("bind failed", 1);
    }
    
    // Listen
    if (listen(listenSock, 5) == -1) {
        quit("listen failed", 1);
    }
    
    // Header
    int headerSize = sizeof(uint32_t);

    int headerBytes = 0;
    uint32_t headerlength;
    
    // Start receiving images
    while (1) {
        cout << "Wait for TCP Connection on port: " << listenPort << "......\n\n";
        /* accept a request from a client */
        if((connectSock = accept(listenSock, (sockaddr *)&clientAddr, &clientAddrLen)) == -1) {
            quit("accepted failed", 1);
        } else {
            // Note that if connect sock is 0, this is error
            cout << "-->Receiving image from " << inet_ntoa(clientAddr.sin_addr) << ":" << ntohs(clientAddr.sin_port) << "..." << endl;
        }
        
        // Build Images...
        while (1) {
            
            // Recevie length
            if ((headerBytes = recv(connectSock, (char *)&headerlength, headerSize, 0)) < 0) {
                cout << strerror(errno) << endl;
                quit("recv failed", 1);
            }
            // Decide the image size
            headerlength = ntohl(headerlength);
            cout << "Header length: " << headerlength << "\n" << endl;
            
            if (headerlength > 0 && headerlength < 20000) {
                pthread_mutex_lock(&mutex1);
                // Image Set
                char sockData[headerlength];
                int bytes = 0;
                
                // Received Image data
                for (int i = 0; i < headerlength; i += bytes) {
                    if ((bytes = recv(connectSock, sockData +i, headerlength  - i, 0)) == -1) {
                        cout << strerror(errno) << endl;
                        quit("recv failed", 1);
                    }
                }
                
                // After get all bytes
                // Convert  the recevied data to OpenCV's Mat
                img1 = imdecode(Mat(1,headerlength, CV_8UC1, &sockData), CV_LOAD_IMAGE_UNCHANGED);
                printf("sock data length: %d sockdata length: %ld \n", headerlength, sizeof(sockData));
                printf("img1 width: %d height: %d\n", img1.rows, img1.cols);
                
                if (img1.rows > 0 && img1.cols > 0) {
                    imshow("Stream Server", img1);
                }
                
                memset(sockData, 0x0, sizeof(sockData));
                memset(&clientAddr, 0x0, sizeof(clientAddr));
                pthread_mutex_unlock(&mutex1);
                
            }
        }
        
    }
    pthread_testcancel();
    usleep(1000); // Take a rest 
}

// Leave from server
void quit(string msg, int retval)
{
    if (retval == 0) {
        cout << (msg == "NULL" ? "" : msg) << "\n" <<endl;
    } else {
        cerr << (msg == "NULL" ? "" : msg) << "\n" <<endl;
    }
    
    if (listenSock){
        close(listenSock);
    }
    
    if (connectSock){
        close(connectSock);
    }
    
    if (!img.empty()){
        (img.release());
    }
    
    pthread_mutex_destroy(&mutex1);
    exit(retval);
}

unsigned long unpacki32(char *buf)
{
    return (buf[0]<<24) | (buf[1]<<16) | (buf[2]<<8) | buf[3];
}
