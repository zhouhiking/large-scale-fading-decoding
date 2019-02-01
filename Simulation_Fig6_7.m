%This Matlab script can be used to reproduce Figures 6,7 in the paper:
%
%Trinh Van Chien, Christopher Mollen and Emil Bjornson, 
%"Large-Scale-Fading Decoding in Cellular Massive MIMO Systems with
%Spatially Correlated Channels", IEEE Transactions on Communications,
%Accepted for publication.
%
%This is version 1.0 (Last edited: 2018-12-19)
%
%License: This code is licensed under the GPLv2 license. If you in any way
%use this code for research that results in publications, please cite our
%paper as described above.


clc; clear; close all;
rng('shuffle'); %Initiate the random number generators with a random seed

nbrOfRealizations = 300; % Number of channels realizations
NBScasesSet = 100:50:300;  % Possible Number of antannas per BS
LengthBS = length(NBScasesSet);
squareLength = 1.00; % Define the coverage area (as a square)
nbrBSs = 4; % Number of BS in the area
K =5; % Number of user per BS% Constraint power
tau= K; 
rho_BS = 1;
Bandwidth = 20e6; % Bandwidth in Hz
noiseFigure = 5;%dB
noiseFloordBm = -174+10*log10(Bandwidth) + noiseFigure;
PowerSymbol= 0.2e3;
DataPowerMatix = PowerSymbol*ones(nbrBSs,K);
PilotPowerMatrix = PowerSymbol*ones(nbrBSs,K);
nbrBSsPerDim = sqrt(nbrBSs); % BSs per dimension
interSiteDistance = squareLength/nbrBSsPerDim; %Distance between BSs in vertical/horizontal direction
% Put out BSs on the grid
locationsGridHorizontal = repmat(interSiteDistance/2:interSiteDistance:squareLength-interSiteDistance/2,[nbrBSsPerDim 1]);
locationsGridVertical = locationsGridHorizontal';
BSpositions = locationsGridHorizontal(:)+1i*locationsGridVertical(:);
% Compute the exact dimension of the square where the users are located
maxDistance = interSiteDistance;

%Compute alterantive BS locations by using wrap arround
wrapHorizontal = repmat([-squareLength 0 squareLength],[3 1]);
wrapVertical = wrapHorizontal';
wrapLocations = wrapHorizontal(:)' + 1i*wrapVertical(:)';
BSpositionsWrapped = repmat(BSpositions, [1 length(wrapLocations)]) + repmat(wrapLocations, [nbrBSs 1]);

%Channel Profile
pentrationlossdB = 20; %dB
ShadowFadingBS = 7;
CorreFactor = 0.5;
NumIter = 500; %Number of Iterations for Optimization
lossovernoiseSave = zeros(nbrBSs, nbrBSs,K, nbrOfRealizations); % Store: Large Scale Fading

SumRateLSFDCorrelatedSMMSE= zeros(nbrOfRealizations,LengthBS);
SumRateCorrelatedSMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateLSFDCorrelatedSMMSE_Appr = zeros(nbrOfRealizations,LengthBS);
SumRateOptLSFDCorrelatedSMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateOptCorrelatedSMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateOptLSFDCorrelatedSMMSE_Appr = zeros(nbrOfRealizations,LengthBS);
SumRateLSFDCorrelatedEMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateCorrelatedEMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateLSFDCorrelatedEMMSE_Appr = zeros(nbrOfRealizations,LengthBS);
SumRateOptLSFDCorrelatedEMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateOptCorrelatedEMMSE = zeros(nbrOfRealizations,LengthBS);
SumRateOptLSFDCorrelatedEMMSE_Appr = zeros(nbrOfRealizations,LengthBS);
ObjFunLFSD_SMMSESave = zeros(LengthBS,NumIter,nbrOfRealizations);
ObjFun_SMMSESave = zeros(LengthBS,NumIter,nbrOfRealizations);
ObjFunLFSD_EMMSESave = zeros(LengthBS,NumIter,nbrOfRealizations);
ObjFun_EMMSESave = zeros(LengthBS,NumIter,nbrOfRealizations);
ObjFunLFSD_SMMSE_ApprSave = zeros(LengthBS,NumIter,nbrOfRealizations);
ObjFunLFSD_EMMSE_ApprSave = zeros(LengthBS,NumIter,nbrOfRealizations);
for iter = 1: nbrOfRealizations
    fprintf('Iteration %d of %d iterations \n', iter, nbrOfRealizations);
    %Prepare to put out UEs in the cells
    UEpositions = zeros(K,nbrBSs);
    perBS = zeros(nbrBSs,1);
    
    AngleNet = zeros(nbrBSs, nbrBSs, K);
    lossovernoise = zeros(nbrBSs, nbrBSs, K);
    EstError = zeros(nbrBSs, nbrBSs, K);

    Amatrix = zeros(nbrBSs, nbrBSs, K);
    IntDataPowerMatrix = sqrt(PowerSymbol)*rand(nbrBSs,K);
    for l=1:nbrBSs
        while min(perBS(l)) < K
            for k=1: K
                posX = rand(1)*maxDistance + real(BSpositions(l)) - maxDistance/2;
                posY = rand(1)*maxDistance + imag(BSpositions(l)) - maxDistance/2;
                PositionTemp = posX + 1i*posY;
                while abs(BSpositions(l) - PositionTemp) < 0.035
                    posX = rand(1)*maxDistance + real(BSpositions(l)) - maxDistance/2;
                    posY = rand(1)*maxDistance + imag(BSpositions(l)) - maxDistance/2;
                    PositionTemp = posX + 1i*posY;
                end
                UEpositions(k,l) = posX + 1i*posY;
            end
            perBS(l) = K;
        end
    end
    % Generate Large Scale Fading and Angles of users to BSs
    for l=1:nbrBSs
        BSSelectedPosK = zeros(nbrBSs,1);
        for k = 1: K
            [distancesSquaredBSj,Position] = min(abs(repmat(UEpositions(k,l),size(BSpositionsWrapped))- BSpositionsWrapped),[],2);
            % Compute the angles of user and BSs
            for BSSelectedIter = 1: nbrBSs
                BSSelectedPosK(BSSelectedIter) = BSpositionsWrapped(BSSelectedIter, Position(BSSelectedIter));
            end
            VectorK = UEpositions(k,l) - BSSelectedPosK;
            AngleK = angle(VectorK);
            AngleNet(:,l,k) = AngleK;
            loss = 128.1 + 37.6*log10(distancesSquaredBSj) + ShadowFadingBS*randn(nbrBSs,1) + noiseFloordBm + pentrationlossdB;
             % Check to ensure that home BS having largest BS
             [Value, Location] = min(loss);
             while Location ~= l
                 Temploss = 128.1 + 37.6*log10(distancesSquaredBSj(l)) + ShadowFadingBS*randn(1) + noiseFloordBm + pentrationlossdB;
                 loss(l) = Temploss;
                 [Value, Location] = min(loss);
             end
             lossovernoiseSave(:,l,k,iter) = rho_BS./(10.^(loss/10));
             lossovernoise(:,l,k) = rho_BS./(10.^(loss/10));
        end
    end
    for IterM = 1 : LengthBS
        NBScases = NBScasesSet(IterM);
        %Vector for correlated Rayleigh channels
        ArrayVector = 0:1:(NBScases-1);

        Im = eye(NBScases);
        CorrelatedFading  = zeros(nbrBSs, nbrBSs,K,NBScases,NBScases);
        EstPhi = zeros(nbrBSs, K, NBScases,NBScases);
        InveseEstPhi = zeros(nbrBSs, K, NBScases,NBScases);
        % Compute autocorrelation matrices 
        for l = 1 : nbrBSs
            for i = 1 : nbrBSs
                for k = 1 : K
                    % Compute autocorrelation matrix
                    CorreVec = lossovernoise(l,i,k)*(CorreFactor*exp(1i*AngleNet(l,i,k))).^ArrayVector;
                    CorrelatedFading(l,i,k,:,:) = toeplitz(CorreVec);


                    % Compute MMSE estimation factors
                    NumFactor = (sqrt(PilotPowerMatrix(i,k))*lossovernoise(l,i,k));
                    DenFactor =  1 + sum(tau*PilotPowerMatrix(:,k).*squeeze(lossovernoise(l,:,k))');
                    EstError(l,i,k) = NumFactor/DenFactor;
                end
            end
        end

        % Compute matrices for MMSE estimation
        for l = 1 : nbrBSs
            for k = 1 : K
                 PhiTemp = Im;
                 for s = 1 : nbrBSs
                      PhiTemp = PhiTemp + tau*PilotPowerMatrix(s,k)*squeeze(CorrelatedFading(l,s,k,:,:));
                 end
                 EstPhi(l, k,:,:) = PhiTemp;
                 InveseEstPhi(l,k,:,:) = inv(PhiTemp);
            end
        end

       % Estimate SINRs with real MMSE
       SINRLSFDCorrelatedSMMSE = Func_LSFD_CorrelatedSMMSE(InveseEstPhi, CorrelatedFading,DataPowerMatix, PilotPowerMatrix,nbrBSs,K,tau);
       SINRCorrelatedSMMSE = Func_CorrelatedSMMSE(InveseEstPhi, CorrelatedFading, DataPowerMatix, PilotPowerMatrix,nbrBSs,K,tau);
       SINRLSFDCorrelatedSMMSE_Appr = Func_LSFD_CorrelatedSMMSE_Appr(lossovernoise,EstError, InveseEstPhi, CorrelatedFading, DataPowerMatix, PilotPowerMatrix,nbrBSs,K,tau, NBScases);
       [SINROptLSFDCorrelatedSMMSE, OptDataPowermatrixLFSD_SMMSE, ObjFunLFSD_SMMSE] = Func_OptLSFD_CorrelatedSMMSE(IntDataPowerMatrix,InveseEstPhi, CorrelatedFading, PowerSymbol, PilotPowerMatrix,nbrBSs,K,tau, NumIter);
       [SINROptCorrelatedSMMSE, OptDataPowermatrix_SMMSE, ObjFun_SMMSE] = Func_Opt_CorrelatedSMMSE(IntDataPowerMatrix,InveseEstPhi, CorrelatedFading, PowerSymbol, PilotPowerMatrix,nbrBSs,K,tau, NumIter);
       [SINROptLSFDCorrelatedSMMSE_Appr, OptDataPowermatrixLFSD_SMMSE_Appr, ObjFunLFSD_SMMSE_Appr] =  Func_OptLSFD_CorrelatedSMMSE_Appr(IntDataPowerMatrix,lossovernoise, EstError, InveseEstPhi, CorrelatedFading, PowerSymbol, PilotPowerMatrix,nbrBSs,K,tau, NBScases,NumIter);
       % Estimate SINRs with element-wise MMSE
       SINRLSFDCorrelatedEMMSE = Func_LSFD_CorrelatedEMMSE(EstError,EstPhi, CorrelatedFading,DataPowerMatix, nbrBSs,K,tau);
       SINRCorrelatedEMMSE = Func_CorrelatedEMMSE(EstError, EstPhi,CorrelatedFading, DataPowerMatix, nbrBSs,K,tau);
       SINRLSFDCorrelatedEMMSE_Appr = Func_LSFD_CorrelatedEMMSE_Appr(lossovernoise, EstError,EstPhi, CorrelatedFading,DataPowerMatix, PilotPowerMatrix, nbrBSs,K,tau, NBScases);
       [SINROptLSFDCorrelatedEMMSE, OptDataPowermatrixLFSD_EMMSE, ObjFunLFSD_EMMSE] = Func_OptLSFD_CorrelatedEMMSE(IntDataPowerMatrix,EstError,EstPhi, CorrelatedFading, PowerSymbol, nbrBSs,K,tau, NumIter);
       [SINROptCorrelatedEMMSE, OptDataPowermatrix_EMMSE, ObjFun_EMMSE] = Func_Opt_CorrelatedEMMSE(IntDataPowerMatrix,EstError,EstPhi, CorrelatedFading, PowerSymbol,nbrBSs,K,tau, NumIter);
       [SINROptLSFDCorrelatedEMMSE_Appr, OptDataPowermatrixLFSD_EMMSE_Appr, ObjFunLFSD_EMMSE_Appr] = Func_OptLSFD_CorrelatedEMMSE_Appr(IntDataPowerMatrix,lossovernoise, EstError,EstPhi, CorrelatedFading, PilotPowerMatrix, PowerSymbol, nbrBSs,K,tau,NBScases, NumIter);

       % Save Sum rate of all methods
       SumRateLSFDCorrelatedSMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINRLSFDCorrelatedSMMSE(:)));
       SumRateCorrelatedSMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINRCorrelatedSMMSE(:)));
       SumRateLSFDCorrelatedSMMSE_Appr(iter,IterM) =(1-K/200)*sum(log2(1+SINRLSFDCorrelatedSMMSE_Appr(:)));
       SumRateOptLSFDCorrelatedSMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINROptLSFDCorrelatedSMMSE(:)));
       SumRateOptCorrelatedSMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINROptCorrelatedSMMSE(:)));
       SumRateOptLSFDCorrelatedSMMSE_Appr(iter,IterM) = (1-K/200)*sum(log2(1+SINROptLSFDCorrelatedSMMSE_Appr(:)));
       SumRateLSFDCorrelatedEMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINRLSFDCorrelatedEMMSE(:)));
       SumRateCorrelatedEMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINRCorrelatedEMMSE(:)));
       SumRateLSFDCorrelatedEMMSE_Appr(iter,IterM) = (1-K/200)*sum(log2(1+SINRLSFDCorrelatedEMMSE_Appr(:)));
       SumRateOptLSFDCorrelatedEMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINROptLSFDCorrelatedEMMSE(:)));
       SumRateOptCorrelatedEMMSE(iter,IterM) = (1-K/200)*sum(log2(1+SINROptCorrelatedEMMSE(:)));
       SumRateOptLSFDCorrelatedEMMSE_Appr(iter,IterM) = (1-K/200)*sum(log2(1+SINROptLSFDCorrelatedEMMSE_Appr(:)));
       ObjFunLFSD_SMMSESave(IterM,:,iter) = (1-K/200)*ObjFunLFSD_SMMSE;
       ObjFun_SMMSESave(IterM,:,iter) = (1-K/200)*ObjFun_SMMSE;
       ObjFunLFSD_EMMSESave(IterM,:,iter) = (1-K/200)*ObjFunLFSD_EMMSE;
       ObjFun_EMMSESave(IterM,:,iter) = (1-K/200)*ObjFun_EMMSE;
       ObjFunLFSD_SMMSE_ApprSave(IterM,:,iter) = (1-K/200)*ObjFunLFSD_SMMSE_Appr;
       ObjFunLFSD_EMMSE_ApprSave(IterM,:,iter) = (1-K/200)*ObjFunLFSD_EMMSE_Appr;
    end
    clear CorrelatedFading  EstPhi  InveseEstPhi;
end

ResultsFigs67.MeanSumRateLSFDCorrelatedSMMSE = mean(SumRateLSFDCorrelatedSMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateCorrelatedSMMSE = mean(SumRateCorrelatedSMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateLSFDCorrelatedSMMSE_Appr = mean(SumRateLSFDCorrelatedSMMSE_Appr,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptLSFDCorrelatedSMMSE =mean(SumRateOptLSFDCorrelatedSMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptCorrelatedSMMSE = mean(SumRateOptCorrelatedSMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptLSFDCorrelatedSMMSE_Appr =mean(SumRateOptLSFDCorrelatedSMMSE_Appr,1)/nbrBSs;
ResultsFigs67.MeanSumRateLSFDCorrelatedEMMSE = mean(SumRateLSFDCorrelatedEMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateCorrelatedEMMSE = mean(SumRateCorrelatedEMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateLSFDCorrelatedEMMSE_Appr = mean(SumRateLSFDCorrelatedEMMSE_Appr,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptLSFDCorrelatedEMMSE = mean(SumRateOptLSFDCorrelatedEMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptCorrelatedEMMSE = mean(SumRateOptCorrelatedEMMSE,1)/nbrBSs;
ResultsFigs67.MeanSumRateOptLSFDCorrelatedEMMSE_Appr = mean(SumRateOptLSFDCorrelatedEMMSE_Appr,1)/nbrBSs;
save Results_Figs67.mat NBScasesSet;

%================= Plot Fig 6 ====================
figure; box on; % With MMSE estimator
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptLSFDCorrelatedSMMSE,'b-');
hold on
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptLSFDCorrelatedSMMSE_Appr,'b-*');
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptCorrelatedSMMSE,'b-s');
plot(NBScasesSet,ResultsFigs67.MeanSumRateLSFDCorrelatedSMMSE,'b-');
plot(NBScasesSet,ResultsFigs67.MeanSumRateLSFDCorrelatedSMMSE_Appr,'b-*');
plot(NBScasesSet,ResultsFigs67.MeanSumRateCorrelatedSMMSE,'b-s');
xlabel('Number of antennas per base station');
ylabel('Sum SE per cell [b/s/Hz]');
legend('Two-layer decoding','Two-layer decoding, Approx.', 'Single-layer decoding');
hold off
grid on;

%================= Plot Fig 7====================
figure; box on; % With EMMSE estimator
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptLSFDCorrelatedEMMSE,'b-');
hold on
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptLSFDCorrelatedEMMSE_Appr,'b-*');
plot(NBScasesSet,ResultsFigs67.MeanSumRateOptCorrelatedEMMSE,'b-s');
plot(NBScasesSet,ResultsFigs67.MeanSumRateLSFDCorrelatedEMMSE,'b-');
plot(NBScasesSet,ResultsFigs67.MeanSumRateLSFDCorrelatedEMMSE_Appr,'b-*');
plot(NBScasesSet,ResultsFigs67.MeanSumRateCorrelatedEMMSE,'b-s');
xlabel('Number of users per cell');
ylabel('Sum SE per cell [b/s/Hz]');
legend('Two-layer decoding','Two-layer decoding, Approx.', 'Single-layer decoding');
hold off
grid on
