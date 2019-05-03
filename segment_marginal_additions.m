%% function segment_marginal_additions
%% (c) 2019 Daniel Stökl Ben Ezra 
%% LGPL 3.0 licence
%% code still experimental
        %% segment marginal additions
        % criteria: a) not in column, b) small distance to a column, c)
        % different from a parchment edge.
        no_col_page=current_page;
        no_col_page(col_result_img>0)=0;
        ecc_props=regionprops(no_col_page,'Eccentricity','PixelIdxList','BoundingBox');
        for ecc_props_i=1:length(ecc_props)
            if ecc_props(ecc_props_i).Eccentricity>0.98;
                no_col_page(ecc_props(ecc_props_i).PixelIdxList)=0;
            end;
            w=ecc_props(ecc_props_i).BoundingBox(3);
            h=ecc_props(ecc_props_i).BoundingBox(4);
            if w*h>max_area_factor_marg*width(i)/reductionfactor*height(i)/reductionfactor
                no_col_page(ecc_props(ecc_props_i).PixelIdxList)=0;
            end;
            
        end;
        no_col_page=bwareaopen(no_col_page,8);
        no_col_page=imdilate(no_col_page,strel('rectangle',[meanheight*colstrelfactor,colstrelfactor*meanheight]));
        no_col_page_labeled=bwlabel(no_col_page);
        marginal_additions=regionprops(no_col_page_labeled,'BoundingBox');
     
        marginal_additions=ceil(cell2mat( struct2cell( marginal_additions)' ))*reductionfactor;
        if ~isempty(marginal_additions)
            marginal_additions=sortrows(marginal_additions,3);
        end;
        [nu_marg_add,~]=size(marginal_additions);
        for k=nu_marg_add:-1:1;
            x1=max(1,marginal_additions(k,1));
            y1=max(1,marginal_additions(k,2));
            x2=min(width(i),marginal_additions(k,1)+marginal_additions(k,3));
            y2=min(height(i),marginal_additions(k,2)+marginal_additions(k,4));
            img_marg=img(y1:y2,x1:x2,:);
            class_category=grp2idx(classify(convnet,imresize(rgb2gray(img_marg),[64,64])));
            if class_category==1
            imwrite(img_marg,fullfile(target_marg_add_folder,'bad',[input_imgs(i).name(1:end-4),'_margAdd_',padstr(num2str(k),3,'0'),'_x1_',num2str(x1),'_y1_',num2str(y1),'_x2_',num2str(x2),'_y2_',num2str(y1),'.png']));
            no_col_page(floor(y1/reductionfactor):ceil(y2/reductionfactor),floor(x1/reductionfactor):ceil(x2/reductionfactor))=0;
             marginal_additions(k,:)=[];
            else
               % mkdir([target_marg_add_folder,'\good']);
                imwrite(img_marg,[target_marg_add_folder,'good',[input_imgs(i).name(1:end-4),'_margAdd_',padstr(num2str(k),3,'0'),'_x1_',num2str(x1),'_y1_',num2str(y1),'_x2_',num2str(x2),'_y2_',num2str(y1),'.png']));
                %figure
              %imshow(img_marg);
            end;
        end;
        [nu_marg_add,~]=size(marginal_additions);
        page_nu_for_margin_table=ones(nu_marg_add,1)*i;
        type_for_margin_table=ones(nu_marg_add,1)*2;
        marg_counter=[1:nu_marg_add]';
        all_marginal_coordinates=[all_marginal_coordinates;[page_nu_for_margin_table,marg_counter,marginal_additions,type_for_margin_table]];
        
       % imshow(no_col_page);