#####Zero Truncated Non Negative Matrix Factorization#####
library(MASS)
library(matrixStats)
library(Matrix)
library(data.table)
library(bayesm)
library(NMF)
library(stringr)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(78594)

####�f�[�^�̔���####
#�f�[�^�̐ݒ�
hh <- 5000   #���[�U�[��
item <- 2000  #�J�e�S���[��
hhpt <- hh*item
k <- 10   #���ݕϐ���
vec_k <- rep(1, k)

##ID�̐ݒ�
user_id0 <- rep(1:hh, rep(item, hh))
item_id0 <- rep(1:item, hh)

##�񕉒l�s����q�����̉���ɏ]���f�[�^�𐶐�
#�K���}���z���p�����[�^��ݒ�
alpha01 <- 0.25; beta01 <- 1.0
alpha02 <- 0.15; beta02 <- 0.85
W <- WT <- matrix(rgamma(hh*k, alpha01, beta01), nrow=hh, ncol=k)   #���[�U�[�����s��
H <- HT <- matrix(rgamma(item*k, alpha02, beta02), nrow=item, ncol=k)   #�A�C�e�������s��
WH <- as.numeric(t(W %*% t(H)))

#�����L���̃x�[�^���z�̃p�����[�^��ݒ�
beta1 <- rbeta(hh, 9.5, 10.0)   #���[�U-�w���m��
beta2 <- rbeta(item, 7.5, 8.0)   #�A�C�e���w���m��

#�|�A�\�����z���f�[�^�𐶐�
y_comp <- rpois(hhpt, WH)


##����������w���f�[�^�𐶐�
#�����x�N�g���𐶐�
z_vec0 <- rbinom(hhpt, 1, beta1[user_id0] * beta2[item_id0])

#�����C���f�b�N�X
z_vec <- z_vec0 * y_comp > 0
index_z <- which(z_vec0==1)
index_z1 <- which(z_vec==1)
index_z0 <- which(z_vec==0)
N <- length(index_z1)

#�����̂���w���x�N�g��
user_id <- user_id0[index_z1]
item_id <- item_id0[index_z1]
y_vec <- y_comp[index_z1]

#�w���x�N�g���ɕϊ�
y <- z_vec0 * y_comp   #�����f�[�^��0�ɕϊ������w���x�N�g��(�ϑ����ꂽ�w���x�N�g��)

##�x�X�g�ȃp�����[�^�ɑ΂���ΐ��ޓx
LLc <- sum(dpois(y_comp, as.numeric(t(W %*% t(H))), log=TRUE))   #���S�f�[�^�ɑ΂���ΐ��ޓx
LLc1 <- sum(dpois(y_comp, as.numeric(t(W %*% t(H))), log=TRUE)[index_z1])   #��[���̃f�[�^�ɑ΂���ΐ��ޓx
LLc2 <- sum(dpois(y_comp[index_z], as.numeric(t(W %*% t(H)))[index_z], log=TRUE))   #�^�̊ϑ��ɑ΂���ΐ��ޓx


####�}���R�t�A�������e�J�����@��NMF�𐄒�####
##�A���S���Y���̐ݒ�
R <- 5000
keep <- 4
burnin <- 1000/keep
iter <- 0
disp <- 10

##���O���z�̐ݒ�
alpha1 <- 0.1; beta1 <- 1
alpha2 <- 0.1; beta2 <- 1

##�p�����[�^�̐^�l
W <- WT
H <- HT; H_t <- t(H)
r <- rowMeans(matrix(z_vec, nrow=hh, ncol=item, byrow=T))
z_vec <- rep(0, hhpt); z_vec[index_z1] <- 1

##�����l�̐ݒ�
W <- matrix(rgamma(hh*k, 0.1, 0.25), nrow=hh, ncol=k)
H <- matrix(rgamma(item*k, 0.1, 0.25), nrow=item, ncol=k); H_t <- t(H)
r <- rowMeans(matrix(z_vec, nrow=hh, ncol=item, byrow=T))
z_vec <- rep(0, hhpt); z_vec[index_z1] <- 1

##�T���v�����O���ʂ̕ۑ��p�z��
W_array <- array(0, dim=c(hh, k, R/keep))
H_array <- array(0, dim=c(k, item, R/keep))
Z_data <- matrix(0, nrow=hh, ncol=item)


##���[�U�[����уA�C�e���̃C���f�b�N�X���쐬
#�ʂɘa����邽�߂̃X�p�[�X�s��
user_dt <- sparseMatrix(user_id, 1:N, x=rep(1, N), dims=c(hh, N))
user_dt_full <- sparseMatrix(user_id0, 1:hhpt, x=rep(1, hhpt), dims=c(hh, hhpt))
item_dt <- sparseMatrix(item_id, 1:N, x=rep(1, N), dims=c(item, N))
item_dt_full <- sparseMatrix(item_id0, 1:hhpt, x=rep(1, hhpt), dims=c(item, hhpt))

#���������l�̃C���f�b�N�X
user_vec_full <- rep(1, hh)
item_vec_full <- rep(1, item)
user_z0 <- user_id0[index_z0]



####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�����L���̐��ݕϐ�Z���T���v�����O
  WH_comp <- as.numeric(t(W %*% t(H)))   #���S�f�[�^�̍s�񕪉��̊��Ғl
  
  #���ݕϐ�z�̊����m���̃p�����[�^
  r_vec <- r[user_z0]   #�������̃x�N�g��
  Li_zeros <- exp(-WH_comp[index_z0])   #�f�[�^���[���̎��̖ޓx
  Posterior_zeros <- r_vec * Li_zeros   #z=1�̎��㕪�z�̃p�����[�^
  z_rate <- Posterior_zeros / (Posterior_zeros + (1-r_vec))   #���ݕϐ��̊����m��
  
  #�񍀕��z������ݕϐ�z���T���v�����O
  z_vec[index_z0] <- rbinom(length(index_z0), 1, z_rate)
  Zi <- matrix(z_vec, nrow=hh, ncol=item, byrow=T)
  r <- rowMeans(Zi)   #���������X�V
  z_comp <- which(z_vec==1); N_comp <- length(z_comp)
  

  ##�K���}���z��胆�[�U�[�����s��W���T���v�����O
  #�⏕�ϐ�lambda���X�V
  H_vec <- H[item_id, ]
  WH <- as.numeric((W[user_id, ] * H_vec) %*% vec_k)    #�ϑ��f�[�^�̍s�񕪉��̊��Ғl
  lambda <- (W[user_id, ] * H_vec) / WH

  #���[�U�[���Ƃ̃K���}���z�̃p�����[�^��ݒ�
  lambda_y <- lambda * y_vec   #�v�f���Ƃ̊��Ғl
  W1 <- as.matrix(user_dt %*% lambda_y + alpha1)
  W2 <- as.matrix((user_dt_full %*% (H[item_id0, ] * z_vec)) + beta1)

  #�K���}���z��胆�[�U�[�����s��W���T���v�����O
  W <- matrix(rgamma(hh*k, W1, W2), nrow=hh, ncol=k)
  #W <- W / matrix(colSums(W), nrow=hh, ncol=k, byrow=T) * hh/5   #�e��x�N�g���𐳋K��
  
  
  ##�K���}���z���A�C�e�������s��H���T���v�����O
  #�⏕�ϐ�lambda���X�V
  W_vec <- W[user_id, ]
  WH <- as.numeric((W_vec * H_vec) %*% vec_k)   #�ϑ��f�[�^�̍s�񕪉��̊��Ғl
  lambda <- (W_vec * H_vec) / WH
  
  #���[�U�[���Ƃ̃K���}���z�̃p�����[�^��ݒ�
  lambda_y <- lambda * y_vec   #�v�f���Ƃ̊��Ғl
  H1 <- as.matrix(item_dt %*% lambda_y + alpha2)
  H2 <- as.matrix((item_dt_full %*% (W[user_id0, ] * z_vec)) + beta2)
  
  #�K���}���z��胆�[�U�[�����s��W���T���v�����O
  H <- matrix(rgamma(item*k, H1, H2), nrow=item, ncol=k)
  

  ##�T���v�����O���ʂ̕ۑ��ƕ\��
  #�T���v�����O���ʂ̊i�[
  if(rp%%keep==0){
    mkeep <- rp/keep
    W_array[, , mkeep] <- W
    H_array[, , mkeep] <- H
    if(rp > burnin){
      Z_data <- Z_data + Zi
    }
  }
  
  #�T���v�����O���ʂ̕\��
  if(rp%%disp==0){
    #�ΐ��ޓx�̌v�Z
    LL <- sum(dpois(y_comp[index_z], as.numeric(t(W %*% t(H)))[index_z], log=TRUE))
    
    #�p�����[�^�̕\��
    print(rp)
    print(c(mean(z_vec), mean(z_vec0)))
    print(c(LL, LLc2))
  }
}


####�T���v�����O���ʂ̗v��ƓK���x####
sum(dpois(as.numeric(t(Data0))[-index_z1], as.numeric(t(W %*% H))[-index_z1], log=TRUE))
sum(dpois(as.numeric(t(Data0))[-index_z1], as.numeric(t(W0 %*% H0))[-index_z1], log=TRUE))

