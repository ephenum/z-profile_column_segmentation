%% preparatory procedure for column segmentation
%% converts all tifs to jpgs and other lighter derivate images

base_folder='C:basefolder'; %
input_imgs_filetype='tif';
source_folder=fullfile(base_folder,'00_input_tif_folios');
jpgtarget_folder=fullfile(base_folder,'01_jpg_folios');
pngtarget_folder=fullfile(base_folder,'01_png_folios');
bwtarget_folder=fullfile(base_folder,'02_binarized_tif_folios');
cleantarget_folder=fullfile(base_folder,'03_cleaned_bw_folios');
mkdir(jpgtarget_folder);
mkdir(pngtarget_folder);
mkdir(bwtarget_folder);
mkdir(cleantarget_folder);
input_imgs=dir(fullfile(source_folder,['*.',input_imgs_filetype]));
write_derivate_imgs=true;
write_png_imgs=false;
write_jpg_imgs=false;
binarize=true;
strel_binarization=strel('disk',30);
nu_imgs=length(input_imgs);
height=zeros(nu_imgs,1);
width=zeros(nu_imgs,1);
for i=1:nu_imgs
    display(i);
    img=imread(fullfile(input_imgs(i).folder,input_imgs(i).name));
    if write_derivate_imgs
        if write_jpg_imgs
            imwrite((img(:,:,1:3)),fullfile(jpgtarget_folder,[input_imgs(i).name(1:end-3),'jpg']));
        end;
        if write_png_imgs
            imwrite((img(:,:,1:3)),fullfile(pngtarget_folder,[input_imgs(i).name(1:end-3),'png']));
        end;
        
        if binarize
            imgBW=binarize_Img(img,strel_binarization);
            imgBWclean=bwareaopen(imgBW,40);
            
            imwrite(imcomplement(imgBW(:,:)),fullfile(bwtarget_folder,[input_imgs(i).name(1:end-3),'png']));
            imwrite(imcomplement(imgBWclean(:,:)),fullfile(cleantarget_folder,[input_imgs(i).name(1:end-3),'png']));
        end;
    end;
end;