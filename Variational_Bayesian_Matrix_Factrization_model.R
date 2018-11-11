#####�����l�̂���ϕ��x�C�Y�s����q����#####
library(MASS)
library(matrixStats)
library(FAdist)
library(NMF)
library(extraDistr)
library(actuar)
library(gtools)
library(caret)
library(reshape2)
library(dplyr)
library(ggplot2)
library(lattice)

#set.seed(5897)

####�f�[�^�̔���####
##�f�[�^�̐ݒ�
k <- 15   #��ꐔ
hh <- 5000   #���[�U�[��
item <- 1500   #�A�C�e����

##�p�����[�^�̐ݒ�
sigma <- 1
A <- A_T <- mvrnorm(hh, rep(0, k), diag(1, k))   #���[�U�[�̓����s��
B <- B_T <- mvrnorm(item, rep(0, k), diag(1, k))   #�A�C�e���̓����s��
beta1 <- rbeta(hh, 8.5, 10.0)   #���[�U-�w���m��
beta2 <- rbeta(item, 5.0, 6.0)   #�A�C�e���w���m��


##���f���Ɋ�Â������ϐ��𐶐�
AB <- A %*% t(B)   #���Ғl
Y <- matrix(0, nrow=hh, ncol=item)
Z <- matrix(0, nrow=hh, ncol=item)

for(j in 1:item){
  #�]���x�N�g���𐶐�
  y_vec <- rnorm(hh, AB[, j], 1)   #���K���z����]���x�N�g���𐶐�
  
  #�����𐶐�
  deficit <- rbinom(hh, 1, beta1 * beta2[j])
  Z[, j] <- deficit   #��������
  
  #�]���x�N�g������
  Y[, j] <- y_vec
}

##ID�ƕ]���x�N�g����ݒ�
N <- length(Z[Z==1])
user_id0 <- rep(1:hh, rep(item, hh))
item_id0 <- rep(1:item, hh)

#�]��������v�f�̂ݒ��o
index_user <- which(as.numeric(t(Z))==1)
user_id <- user_id0[index_user]
item_id <- item_id0[index_user]
y_vec <- as.numeric(t(Y))

#�]���x�N�g����1�`5�̊Ԃ̗��U�l�Ɏ��߂�
score_mu <- 3   #���σX�R�A
y0 <- as.numeric(round(scale(y_vec) + score_mu))   #����3�̐����l�]���x�N�g��
y0[y0 < 1] <- 1
y0[y0 > 5] <- 5
y <- y0[index_user]   #�����̂���]���x�N�g��
Y <- matrix(y0, nrow=hh, ncol=item, byrow=T)   #�]���x�N�g���̊��S�f�[�^


##�C���f�b�N�X�̍쐬
index_user <- list()
index_item <- list()
for(i in 1:hh){
  index_user[[i]] <- which(user_id==i)
}
for(j in 1:item){
  index_item[[j]] <- which(item_id==j)
}

####�ϕ��x�C�Y�@�Ńp�����[�^�𐄒�####
##�A���S���Y���̐ݒ�
LL1 <- -100000000   #�ΐ��ޓx�̏����l
tol <- 1
iter <- 1
dl <- 100

##���O���z�̐ݒ�
sigma <- 1
Ca <- diag(1, k)
Cb <- diag(1, k)

##�����l�̐ݒ�
Cov_A <- array(diag(1, k), dim=c(k, k, hh))
Cov_B <- array(diag(1, k), dim=c(k, k, item))
A <- mvrnorm(hh, rep(0.0, k), diag(0.5, k))
B <- mvrnorm(item, rep(0.0, k), diag(0.5, k))


####�ϕ��x�C�Y�@�Ńp�����[�^���X�V####
while(abs(dl) > tol){   #dl��tol�ȏ�Ȃ�J��Ԃ�

  ##���[�U�[�����s��̃p�����[�^���X�V
  A <- matrix(0, nrow=hh, ncol=k)
  Cov_A <- array(0, dim=c(k, k, hh))
  
  #���U�������X�V
  for(i in 1:hh){
    index <- item_id[index_user[[i]]]
    Cov_sum <- matrix(0, k, k)
    for(j in 1:length(index)){
      Cov_sum <- Cov_sum + Cov_B[, , index[j]]
    }
    Cov_A[, , i] <- sigma^2 * (solve((t(B[index, ]) %*% B[index, ] + Cov_sum) + sigma^2 * solve(Ca)))
  }
  
  #���[�U�[���Ƃɓ����x�N�g�����X�V
  for(i in 1:hh){
    A[i, ] <- sigma^-2 * Cov_A[, , i] %*% colSums(y[index_user[[i]]] * B[item_id[index_user[[i]]], ])
  }
  
  ##�A�C�e�������s��̃p�����[�^���X�V
  #���U�������X�V
  B <- matrix(0, nrow=item, ncol=k)
  Cov_B <- array(0, dim=c(k, k, item))
  
  #���U�������X�V
  for(j in 1:item){
    index <- user_id[index_item[[j]]]
    Cov_sum <- matrix(0, k, k)
    for(l in 1:length(index)){
      Cov_sum <- Cov_sum + Cov_A[, , index[l]]
    }
    Cov_B[, , j] <- sigma^2 * solve((t(A[index, ]) %*% A[index, ] + Cov_sum) + sigma^2 * solve(Cb))
  }
  
  #�A�C�e�����Ƃɓ����x�N�g�����X�V
  for(j in 1:item){
    B[j, ] <- sigma^-2 * Cov_B[, , j] %*% colSums(y[index_item[[j]]] * A[user_id[index_item[[j]]], ])
  }
  
  ##�n�C�p�[�p�����[�^���X�V
  #�p�����[�^�̎��O���z���X�V
  Ca <- diag((colSums(A^2) + diag(apply(Cov_A, c(1, 2), sum))) / hh)
  Cb <- diag((colSums(B^2) + diag(apply(Cov_B, c(1, 2), sum))) / item)
  
  #�W���΍����X�V
  score <- rowSums(A[user_id, ] * B[item_id, ])
  sigma <- sqrt(sum((y - score)^2) / length(y))
  
  
  ##�A���S���Y���̎�������
  LL <- sum(dnorm(y, score, sigma, log=TRUE))   #�ΐ��ޓx���X�V
  iter <- iter + 1
  dl <- LL - LL1
  LL1 <- LL
  print(LL)
}

##���S�f�[�^�ɑ΂�����덷�𐄒�
#�]���x�N�g���ƌ����x�N�g����ݒ�
z_vec <- as.numeric(t(Z))
y_vec <- as.numeric(t(Y))
mu_vec <- as.numeric(t(A %*% t(B)))

#�ϑ��f�[�^�̓��덷
er_obz <- sum((y_vec[z_vec==1] - mu_vec[z_vec==1])^2)
er_obz / sum(z_vec==1)

#�����f�[�^�̓��덷
er_na <- sum((y_vec[z_vec==0] - mu_vec[z_vec==0])^2)
er_na / sum(z_vec==0)
cbind(z_vec, y_vec, round(mu_vec, 2))