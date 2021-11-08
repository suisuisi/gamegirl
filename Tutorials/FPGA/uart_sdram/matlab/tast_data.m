fid=fopen('test_data.txt','w+');
%for i =1:16
    for j = 1:100
        fprintf(fid,'%02x ',j);
    end
%end
fclose(fid);
