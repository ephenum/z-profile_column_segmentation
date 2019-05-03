function [imgcube,height,width]=create_cube(input_imgs,reductionfactor)

%% this function builds a cube out of all bw input images in order to calculate the z-profile
    nu_imgs=length(input_imgs);
    display('==================================');
    display('get dimensions of all images');
    tic
    height=zeros(nu_imgs,1);
    width=zeros(nu_imgs,1);
    for i=1:nu_imgs;
        if mod(i,50)==0;display(i);toc;end;
        imginfo=imfinfo(fullfile(input_imgs(i).folder,input_imgs(i).name));
        height(i)=imginfo.Height;
        width(i)=imginfo.Width;
    end;
    height_reduced=round(height/reductionfactor,0);
    width_reduced=round(width/reductionfactor,0);
    maxheight=max(height_reduced);
    maxwidth=max(width_reduced);
    imgcube=zeros(maxheight,maxwidth,nu_imgs);
    
    display('==================================');
    display(['building cube of ',num2str(nu_imgs),' images with reduction factor ',num2str(reductionfactor)]);
    
    for i=1:nu_imgs;
        if mod(i,50)==0;display(i);end;
        img=imread(fullfile(input_imgs(i).folder,input_imgs(i).name));
        img=imresize(img,[height_reduced(i),width_reduced(i)]);
        imgcube(1:height_reduced(i),1:width_reduced(i),i)=img;
    end;