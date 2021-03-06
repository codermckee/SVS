clear all;
addpath('src'); 

visual = 0; %whether to get the visual results

param = testConfig();

model = param.model(2);

%deploy the testing network
net = caffe.Net(model.deployFile,'test');
preModel = model.preModel;
net.copy_from(preModel); 

batch_size = model.batchSize;
dim = [model.height model.width];
dim_large = [model.H model.W];
stride = model.stride;
channel = model.channel;

testSet = load('../data/testing/testKittiEigen.mat');
test = testSet.test;
clear testSet;

for batch = 1:697
    fprintf('Run batch %d/697...\n',batch);
    
    ind = batch;  img = test.left{ind};

    dim_ori = [size(img,1) size(img,2)];

    [data_,left_large_,shift] = transformation_svs(img,dim,dim_large,channel,stride);
   
    net.blobs('data').set_data(single(data_));
    for k =1:channel
       ss = strcat('dis',num2str(k-1));
       net.blobs(ss).set_data(single(shift(:,:,:,k)));
    end  
    net.blobs('left_ori').set_data(single(left_large_));
    net.forward_prefilled();
    
    clear data_ left_large_ shift;
    
    disp = -net.blobs('predict_flow0').get_data();
    disp_ = permute(disp,[2 1 3]);
    disp_ = imresize(disp_,[dim_ori(1) dim_ori(2)],'nearest');
    disp_ = disp_ / dim_large(2) * dim_ori(2);
    dep = test.baseline{ind} * test.focal{ind} ./ disp_;
    gt = test.depth{ind};
    if(size(dep,1)~=size(gt,1) ||size(dep,2)~=size(gt,2))
       error('Size not match...Please check...\n');
    end    
    pred.dep{ind} = dep;
    pred.gt{ind} = gt;
       
    if(visual)
        if(exist('img_end2end','dir')~=7)
            mkdir('./img_end2end/')
        end    
        right = net.blobs('img1_aug').get_data() * 255;
        right = imresize(uint8(right(:,:,[3 2 1])),[size(img,2) size(img,1)],'bilinear');
        imwrite(permute(right,[2 1 3]),['./img/img_' num2str(batch) '_right.png']);

        imwrite(img,['./img_end2end/img_' num2str(batch) '.png']);
        imwrite(test.right{ind},['./img_end2end/img_' num2str(batch) '_rightGT.png']);
        dep2 = dep;dep2(dep2>80)=80;
        imwrite(dep2/max(dep2(:)),['./img_end2end/img_' num2str(batch) '_pred.png']);
        imwrite(gt,['./img_end2end/img_' num2str(batch) '_gt.png']);
    end
end

%%get the metrics
error_1 = zeros([7 697]);
error_2 = zeros([7 697]);
for k = 1:697
    error_1(:,k) = calError(pred.dep{k},pred.gt{k},0.001,80,'garg');
    error_2(:,k) = calError(pred.dep{k},pred.gt{k},1,50,'garg');
end    
error_mean_1 = mean(error_1,2);
error_mean_2 = mean(error_2,2);

%Print result matrics
print_Result(error_mean_1,error_mean_2);
