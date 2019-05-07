%% simple z-profile based column segmentation for regular manuscripts
%% =================================
%% (c) 2018 Daniel Stökl Ben Ezra, EPHE, PSL
%% LGPL licence version 3.0
%% =================================

%% parameters, most of which could be automatized
expected_nu_cols=2; % could be calculated from cube, but I am too lazy
colstrelfactor=4; %structuring element to create column block by overcoming line distance. average line distace could be calculated from cube
reductionfactor=8; %factor to reduce image size to fit computer memory depends on memory size of system used. slighly influences precision.
max_area_factor_marg=0.4; %maximal area part of the BoundingBox of a marginal addition on the page;
safety_frame_x=200; %extrapixels left and right to calculated column to be surer to catch also letter ends that did not survive well the binarization. One does not need this above and below due to the character of the morphological transformation
writing_direction='ltr'; % set to rtl or ltr to influence numbering of sequence of columns
base_folder='C:base_folder'; % main folder for input and output. change in order to fit the overall directory on your computer. See below for subfolder names.
source_folder=fullfile(base_folder,'03_cleaned_bw_folios'); % source folder for image
input_img_file_type='png'; %input image format
output_color_img_type='jpg'; %output image format
trained_cnn_filename='convnet4.mat'; % trained cnn for the distinction of candidates for marginal notes and noise

%% result effecting flags (see below in the code for the factor they influence)
with_clear_border=true;               
keep_largest_n_ccs_only=true;          
link_ccs_in_same_col=true;          
delete_smaller_ccs=true;
with_separation_line_between_columns=false;      % hard cut between the n columns in any case. good if there are marginal additions that might connect two columns. but will cut single columns in two.                           
%% program step flags 
start_img=1;                                end_img=0;            %%end_img=0: all images; number of starting and ending image of the input_img_file_type found in the source directory        
calculate_cube=true;                    restart_column_calculation=false;
write_col_csv=true;                     write_overlay=true;
write_columns=true;                    with_segment_marginal_additions=false;
load_nn_for_segment_marginal_additions=false;
write_marginal_additions=false;  write_img_size_csv=false;
visualize_average_images=false;

%% subfolder names and file types
color_img_folder=fullfile(base_folder,'00_input_tif_folios');
overlay_folder=fullfile(base_folder,'04_layout_overlay');mkdir(overlay_folder);
target_col_folder=fullfile(base_folder,'05_columns');mkdir(target_col_folder);
target_colBW_folder=fullfile(target_col_folder,'BW');mkdir(target_colBW_folder);
target_marg_add_folder=fullfile(base_folder,'06_marginal_additions');mkdir(target_marg_add_folder);
mkdir(fullfile(target_marg_add_folder,'bad'));mkdir(fullfile(target_marg_add_folder,'good'));
column_direction_factor=get_writing_direction(writing_direction)

input_imgs=dir(fullfile(source_folder,['*.',input_img_file_type]));
nu_imgs=length(input_imgs);
all_marginal_coordinates=zeros(1,7);
%% calculate cube
if calculate_cube
    [imgcube,height,width]=create_cube(input_imgs,reductionfactor);
    
    display('==================================');
    display('construct z profile image');
    
    average_img_impair=sum(imgcube(:,:,1:2:end),3)/nu_imgs/2;
    imwrite(average_img_impair,fullfile(base_folder,'average_img_impair.png'));
    average_img_pair=sum(imgcube(:,:,2:2:end),3)/nu_imgs/2;
    
    imwrite(average_img_pair,fullfile(base_folder,'average_img_pair.png'));
    if visualize_average_images
        figure;imagesc(average_img_impair);title('impair average image')
        figure;imagesc(average_img_pair);title('pair average image');
    end;
    [result_img_impair,column_coordinates_impair]=extract_columns_from_average_img(average_img_impair,0,expected_nu_cols);
    [result_img_pair,column_coordinates_pair]=extract_columns_from_average_img(average_img_pair,0,expected_nu_cols);
end
if load_nn_for_segment_marginal_additions

display('==================================');
display('load_nn_for_segment_marginal_additions');    
    load(trained_cnn_filename);
end
%% calculate individual column coordinates

display('==================================');
display('calculate individual column coordinates');
if restart_column_calculation
    all_column_coordinates=zeros(nu_imgs,7);
    column_counter=0;
end;
if end_img==0;end_img=nu_imgs;end;
for i=start_img:end_img;
    input_imgs(i).name
    for col_nu=1:expected_nu_cols
        list_good_ccs{col_nu}=[];
    end;
    if mod(i,50)==0;display(i);end;
    if mod(i,2)==0
        model_layout_analysis=result_img_pair;
        model_column_coordinates=column_coordinates_pair;
    else
        model_layout_analysis=result_img_impair;
        model_column_coordinates=column_coordinates_impair;
    end;
    %% calculate size of morphological transformation.
    current_page=imcomplement(im2bw(imgcube(:,:,i)));
    column_region_letter_img=imfill(model_layout_analysis,'holes').*current_page; %mask expected columns over image
    ccs=bwconncomp(column_region_letter_img);
    stats=regionprops(ccs,'BoundingBox');
    
    if ~isempty(stats)
        stats=cell2mat( struct2cell( stats') );
        stats=reshape(stats,4,size(stats,3));
        stats=stats';
        meanheight=median(stats(:,4)); %calculate median letter height
        colstrel=strel('line',colstrelfactor*meanheight,90);
        if delete_smaller_ccs
            labeled_page_img=bwlabel(current_page);
            ccs=bwconncomp(labeled_page_img);
            stats=regionprops(ccs,'BoundingBox');
            stats=cell2mat( struct2cell( stats') );
            stats=reshape(stats,4,size(stats,3));
            stats=stats';
            colimg=ismember(labeled_page_img,find(stats(:,4)>=meanheight));
        else
            colimg=current_page;
        end;
        colimg=imdilate(colimg,colstrel); %smear with the help of the median letter height
        
        if with_clear_border
            colimg=imclearborder(colimg);
            % clear border to avoid some cases of ccs framing the columns while having their centroid inside
            % this generates the problem that on dark pages at beginning of document especially the whole page is one cc and gets cleared.
        end;
        
        if with_separation_line_between_columns
            % avoids two columns linked together through marginal addition
            for col_nu=2:expected_nu_cols
                x=floor(mean(model_column_coordinates(col_nu-1,1)+model_column_coordinates(col_nu-1,3),model_column_coordinates(col_nu,1)));
                colimg(:,x)=0;
            end
        end;
        colimg_labeled=bwlabel(colimg);
        %% keep only candidates with Centroids inside suspect area
        colimgccs=regionprops(colimg_labeled,'Centroid','PixelIdxList');
        
        for cc_nu=1:length(colimgccs);
            good_cc=false;
            for column_nu=1:expected_nu_cols
                if ( (colimgccs(cc_nu).Centroid(1)>=model_column_coordinates(column_nu,1)) ...
                        & (colimgccs(cc_nu).Centroid(1)<=model_column_coordinates(column_nu,1)+model_column_coordinates(column_nu,3)) ...
                        &    (colimgccs(cc_nu).Centroid(2)>=model_column_coordinates(column_nu,2)) ...
                        & (colimgccs(cc_nu).Centroid(2)<=model_column_coordinates(column_nu,2)+model_column_coordinates(column_nu,4))...
                        )
                    good_cc=true;
                    list_good_ccs{column_nu}=[list_good_ccs{column_nu},cc_nu];
                end;
            end
            if ~good_cc
                colimg_labeled(colimgccs(cc_nu).PixelIdxList)=0;
            end;
        end
        
        %% link all legimitate ccs via their centroids
        if link_ccs_in_same_col
            for col_nu=1:expected_nu_cols
                if length(list_good_ccs{col_nu})>1
                    cc1x=max(1,floor(colimgccs(list_good_ccs{col_nu}(1)).Centroid(1)));
                    cc1y=max(1,floor(colimgccs(list_good_ccs{col_nu}(1)).Centroid(2)));
                    n_good_ccs=length(list_good_ccs{col_nu});
                    for good_cc_i=2:n_good_ccs
                        cc2x=max(1,floor(colimgccs(list_good_ccs{col_nu}(good_cc_i)).Centroid(1)));
                        cc2y=max(1,floor(colimgccs(list_good_ccs{col_nu}(good_cc_i)).Centroid(2)));
                        if cc1x>=cc2x ccall_x=[cc2x:cc1x];else ccall_x=[cc1x:cc2x];end;
                        if cc1y>=cc2y ccall_y=[cc2y:cc1y];else ccall_y=[cc1y:cc2y];;end;
                        colimg_labeled(ccall_y,ccall_x)=255;
                    end
                end;
            end;
        end;
        colimg_labeled=im2bw(imfill(colimg_labeled,'holes'));
        %% extract coordinates of two largest ccs
        if keep_largest_n_ccs_only
            colimg_labeled=bwareafilt(colimg_labeled,expected_nu_cols,'largest');
        end;
        column_ccs=regionprops(colimg_labeled,'BoundingBox');
        column_coordinates=ceil(cell2mat( struct2cell( column_ccs)' ))*reductionfactor;
        if ~isempty(column_coordinates)
            column_coordinates=sortrows(column_coordinates,column_direction_factor);
        end;
                
        [nu_cols,~]=size(column_coordinates);
        if write_columns | write_marginal_additions
            img=imread([color_img_folder,'\',input_imgs(i).name(1:end-3),output_color_img_type]);
        end;

        %% create matrix of all column coordinates
        col_result_img=zeros(size(imgcube,1),size(imgcube,2));
        for k=1:nu_cols
            column_counter=column_counter+1;
            x1=max(1,column_coordinates(k,1)-safety_frame_x);
            y1=max(1,column_coordinates(k,2));
            x2=min(width(i),column_coordinates(k,1)+column_coordinates(k,3)+safety_frame_x);
            y2=min(height(i),column_coordinates(k,2)+column_coordinates(k,4));
            all_column_coordinates(column_counter,:)=[i,k,x1,y1,x2,y2,1];
            
            col_result_img(floor((y1:y2)/reductionfactor),floor((x1:x2)/reductionfactor))=255-(k-1)*100;
            if write_columns;
                col=img(y1:y2,x1:x2,:);
                imwrite(col,fullfile(target_col_folder,[input_imgs(i).name(1:end-4),'_col_',padstr(num2str(k),2,'0'),'_x1_',num2str(x1),'_y1_',num2str(y1),'_x2_',num2str(x2),'_y2_',num2str(y2),'.png']));
                colBW=imcomplement(binarize_Img(col,strel('disk',30)));
                imwrite(colBW,fullfile(target_colBW_folder,[input_imgs(i).name(1:end-4),'_col_',padstr(num2str(k),2,'0'),'_x1_',num2str(x1),'_y1_',num2str(y1),'_x2_',num2str(x2),'_y2_',num2str(y2),'.png']));
            end;
        end;
        
        if with_segment_marginal_additions
            segment_marginal_additions
            result_img=imcomplement(uint8(overlay_average_img_columns(current_page*255,no_col_page*255+current_page*255,col_result_img+current_page*255)));
        else;
            result_img=imcomplement(uint8(overlay_average_img_columns(((current_page))*255,((current_page))*255,(col_result_img))));
        end;
        imwrite(imresize(result_img(1:round(height(i)/reductionfactor,0),1:round(width(i)/reductionfactor,0),:),[height(i),width(i)]),[overlay_folder,'\',input_imgs(i).name]);
        
    end;
end;
if write_col_csv
    csvwrite(fullfile(base_folder,'all_cols.csv'),all_column_coordinates);
    if with_segment_marginal_additions & write_marginal_additions
    csvwrite(fullfile(base_folder,'all_marginal_additions.csv'),all_marginal_coordinates);
    end
end;