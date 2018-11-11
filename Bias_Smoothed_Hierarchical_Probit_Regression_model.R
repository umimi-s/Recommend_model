#####Bias Smoothed Hierarchical Probit Regression model#####
library(MASS)
library(Matrix)
library(matrixStats)
library(data.table)
library(bayesm)
library(MCMCpack)
library(condMVNorm)
library(extraDistr)
library(reshape2)
library(actuar)
library(extraDistr)
library(caret)
library(dplyr)
library(foreach)
library(ggplot2)
library(lattice)


####�C�ӂ̕��U�����U�s����쐬������֐�####
##���ϗʐ��K���z����̗����𔭐�������
#�C�ӂ̑��֍s������֐����`
corrM <- function(col, lower, upper, eigen_lower, eigen_upper){
  diag(1, col, col)
  
  rho <- matrix(runif(col^2, lower, upper), col, col)
  rho[upper.tri(rho)] <- 0
  Sigma <- rho + t(rho)
  diag(Sigma) <- 1
  (X.Sigma <- eigen(Sigma))
  (Lambda <- diag(X.Sigma$values))
  P <- X.Sigma$vector
  
  #�V�������֍s��̒�`�ƑΊp������1�ɂ���
  (Lambda.modified <- ifelse(Lambda < 0, runif(1, eigen_lower, eigen_upper), Lambda))
  x.modified <- P %*% Lambda.modified %*% t(P)
  normalization.factor <- matrix(diag(x.modified),nrow = nrow(x.modified),ncol=1)^0.5
  Sigma <- x.modified <- x.modified / (normalization.factor %*% t(normalization.factor))
  diag(Sigma) <- 1
  round(Sigma, digits=3)
  return(Sigma)
}

##���֍s�񂩂番�U�����U�s����쐬����֐����`
covmatrix <- function(col, corM, lower, upper){
  m <- abs(runif(col, lower, upper))
  c <- matrix(0, col, col)
  for(i in 1:col){
    for(j in 1:col){
      c[i, j] <- sqrt(m[i]) * sqrt(m[j])
    }
  }
  diag(c) <- m
  cc <- c * corM
  #�ŗL�l�����ŋ����I�ɐ���l�s��ɏC������
  UDU <- eigen(cc)
  val <- UDU$values
  vec <- UDU$vectors
  D <- ifelse(val < 0, val + abs(val) + 0.00001, val)
  covM <- vec %*% diag(D) %*% t(vec)
  data <- list(covM, cc,  m)
  names(data) <- c("covariance", "cc", "mu")
  return(data)
}

####�f�[�^�̔���####
##�f�[�^�̐ݒ�
hh <- 5000   #���[�U�[��
item <- 2000   #�A�C�e����
context <- 200   #�R���e�L�X�g��
N0 <- hh*item


##�����x�N�g����ID��ݒ�
#ID�����ݒ�
item_id0 <- rep(1:item, rep(context, item))
context_id0 <- rep(1:context, item)
n <- length(item_id0)

#�v�f���Ƃ̏o���m��
beta1 <- rbeta(hh, 3.0, 36.0)
par2 <- rbeta(item, 3.0, 15.0)
par3 <- rbeta(context, 0.6, 8.0)


#���[�U�[���Ƃ�ID���쐬
user_id_list <- item_id_list <- context_id_list <- list()
for(i in 1:hh){
  if(i%%100==0){
    print(i)
  }
  #�m���𐶐�
  beta2 <- rbeta(item, par2*2.0, (1-par2)*2.0)
  beta3 <- rbeta(context, par3*1.5, (1-par3)*1.5)
  beta_vec2 <- beta2[item_id0]
  beta_vec3 <- beta3[context_id0]
  
  #�����x�N�g���𐶐�
  prob <- beta1[i] * beta_vec2 * beta_vec3
  deficit <- rbinom(n, 1, prob)
  index_z <- which(deficit==1)
  
  #ID��ݒ�
  user_id_list[[i]] <- rep(i, n)[index_z]
  item_id_list[[i]] <- item_id0[index_z]
  context_id_list[[i]] <- context_id0[index_z]
}
#���X�g��ϊ�
user_id <- unlist(user_id_list)
item_id <- unlist(item_id_list)
context_id <- unlist(context_id_list)
N <- length(user_id)


#���[�U�[�~�R���e�L�X�g��ID
uw_index <- paste(user_id, context_id, sep="-")
uw_id <- left_join(data.frame(id=uw_index, no_vec=1:length(uw_index)),
                   data.frame(id=unique(uw_index), no=1:length(unique(uw_index))), by="id")$no

#�A�C�e���~�R���e�L�X�g��ID
vw_index <- paste(item_id, context_id, sep="-")
vw_id <- left_join(data.frame(id=vw_index, no_vec=1:length(vw_index)),
                   data.frame(id=unique(vw_index), no=1:length(unique(vw_index))), by="id")$no


##�����ϐ����Ó��ɂȂ�܂Ńp�����[�^�̐������J��Ԃ�
for(rp in 1:1000){
  print(rp)
  
  ##�f���x�N�g���𐶐�
  k1 <- 2; k2 <- 3; k3 <- 4
  x1 <- matrix(runif(N*k1, 0, 1), nrow=N, ncol=k1)
  x2 <- matrix(0, nrow=N, ncol=k2)
  for(j in 1:k2){
    pr <- runif(1, 0.25, 0.55)
    x2[, j] <- rbinom(N, 1, pr)
  }
  x3 <- rmnom(N, 1, runif(k3, 0.2, 1.25)); x3 <- x3[, -which.min(colSums(x3))]
  x <- cbind(x1, x2, x3)   #�f�[�^������
  
  
  ##�K�w���f���̐����ϐ��𐶐�
  #���[�U�[�̐����ϐ�
  k1 <- 1; k2 <- 3; k3 <- 5
  u1 <- matrix(runif(hh*k1, 0, 1), nrow=hh, ncol=k1)
  u2 <- matrix(0, nrow=hh, ncol=k2)
  for(j in 1:k2){
    pr <- runif(1, 0.25, 0.55)
    u2[, j] <- rbinom(hh, 1, pr)
  }
  u3 <- rmnom(hh, 1, runif(k3, 0.2, 1.25)); u3 <- u3[, -which.min(colSums(u3))]
  u <- cbind(1, u1, u2, u3)   #�f�[�^������
  
  #�A�C�e���̐����ϐ�
  k1 <- 2; k2 <- 2; k3 <- 4
  v1 <- matrix(runif(item*k1, 0, 1), nrow=item, ncol=k1)
  v2 <- matrix(0, nrow=item, ncol=k2)
  for(j in 1:k2){
    pr <- runif(1, 0.25, 0.55)
    v2[, j] <- rbinom(item, 1, pr)
  }
  v3 <- rmnom(item, 1, runif(k3, 0.2, 1.25)); v3 <- v3[, -which.min(colSums(v3))]
  v <- cbind(1, v1, v2, v3)   #�f�[�^������
  
  #�R���e�L�X�g�̐����ϐ�
  k1 <- 2; k2 <- 2; k2 <- 3
  w1 <- matrix(runif(item*k1, 0, 1), nrow=context, ncol=k1)
  w2 <- matrix(0, nrow=context, ncol=k2)
  for(j in 1:k2){
    pr <- runif(1, 0.25, 0.55)
    w2[, j] <- rbinom(context, 1, pr)
  }
  w3 <- rmnom(context, 1, runif(k2, 0.2, 1.25)); w3 <- w3[, -which.min(colSums(w2))]
  w <- cbind(1, w1, w2, w3)   #�f�[�^������
  
  
  #�f���x�N�g���̉�A�W���𐶐�
  beta <- rep(0, ncol(x))
  for(j in 1:ncol(x)){
    beta[j] <- runif(1, -0.8, 1.2)
  }
  betat <- beta
  
  
  ##�K�w���f���̃p�����[�^�𐶐�
  ##���[�U�[�x�[�X�̊K�w���f���̃p�����[�^
  tau_u <- tau_ut <- 0.5   #�W���΍�
  
  #��A�W����ݒ�
  alpha_u <- rep(0, ncol(u))
  for(j in 1:ncol(u)){
    if(j==1){
      alpha_u[j] <- runif(1, -1.3, -0.5)
    } else {
      alpha_u[j] <- runif(1, -0.4, 0.6)
    }
  }
  alpha_ut <- alpha_u
  
  #��A���f�����烆�[�U�[�ʂ̉�A�p�����[�^�𐶐�
  theta_ut <- theta_u <- as.numeric(u %*% alpha_u + rnorm(hh, 0, tau_u))
  
  
  ##�A�C�e���x�[�X�̊K�w���f���̃p�����[�^
  tau_v <- tau_vt <- 0.7   #�W���΍�
  
  #��A�W����ݒ�
  alpha_v <- rep(0, ncol(v))
  for(j in 1:ncol(v)){
    if(j==1){
      alpha_v[j] <- runif(1, -1.2, -0.3)
    } else {
      alpha_v[j] <- runif(1, -0.6, 0.7)
    }
  }
  alpha_vt <- alpha_v
  
  #��A���f������A�C�e���ʂ̉�A�p�����[�^�𐶐�
  theta_vt <- theta_v <- as.numeric(v %*% alpha_v + rnorm(item, 0, tau_v))
  
  
  ##�R���e�L�X�g�x�[�X�̊K�w���f���̃p�����[�^
  tau_w <- tau_wt <- 0.4   #�W���΍�
  
  #��A�W����ݒ�
  kw <- 2
  alpha_w <- matrix(0, nrow=ncol(w), ncol=kw)
  for(j in 1:ncol(w)){
    if(j==1){
      alpha_w[j, ] <- runif(kw, 0.2, 0.5)
    } else {
      alpha_w[j, ] <- runif(kw, 0.2, 0.7)
    }
  }
  alpha_wt <- alpha_w
  
  #��A���f������R���e�L�X�g�ʂ̉�A�p�����[�^�𐶐�
  theta_wt <- theta_w <- w %*% alpha_w + mvrnorm(context, rep(0, kw), tau_w^2 * diag(kw))
  theta_wt1 <- theta_w1 <- theta_w[, 1]
  theta_wt2 <- theta_w2 <- theta_w[, 2]
  
  ##�R���e�L�X�g�ˑ��̃��[�U�[����уA�C�e���o�C�A�X�̃p�����[�^�𐶐�
  #�R���e�L�X�g�ˑ��̕ϗʌ���
  tau_uwt <- tau_uw <- 0.4; tau_vwt <- tau_vw <- 0.4
  alpha_uwt <- alpha_uw <- rnorm(unique(uw_id), 0, tau_uw)
  alpha_vwt <- alpha_vw <- rnorm(unique(vw_id), 0, tau_vw)
  
  #�R���e�L�X�g�ˑ��o�C�A�X�������p�����[�^
  theta_uwt <- theta_uw <- alpha_uw[uw_id] + theta_u[user_id] * theta_w1[context_id] 
  theta_vwt <- theta_vw <- alpha_vw[vw_id] + theta_v[item_id] * theta_w2[context_id] 
  
  
  ##�v���r�b�g���f�����牞���ϐ��𐶐�
  #���݌��p�̐���
  mu <- x %*% beta + theta_uw + theta_vw
  U <- rnorm(N, mu, 1)
  
  #�����ϐ��𐶐�
  y <- as.numeric(U > 0)
  if(mean(y) > 0.3 & mean(y) < 0.4) break   #break����
}

#####�}���R�t�A�������e�J�����@��BSHP���f���𐄒�####
##�ؒf���K���z�̗����𔭐�������֐�
rtnorm <- function(mu, sigma, a, b, L){
  FA <- pnorm(a, mu, sigma)
  FB <- pnorm(b, mu, sigma)
  par <- matrix(0, nrow=length(mu), ncol=L)
  for(j in 1:L){
    par[, j] <- qnorm(runif(length(mu))*(FB-FA)+FA, mu, sigma)
  }
  return(par)
}

##�A���S���Y���̐ݒ�
LL1 <- -100000000   #�ΐ��ޓx�̏����l
R <- 2000
keep <- 2  
iter <- 0
burnin <- 500/keep
disp <- 5

##�C���f�b�N�X���쐬
user_index <- list()
for(i in 1:hh){
  user_index[[i]] <- which(user_id==i)
}
item_index <- list()
for(j in 1:item){
  item_index[[j]] <- which(item_id==j)
}
context_index <- list()
for(j in 1:context){
  context_index[[j]] <- which(context_id==j)
}

#�R���e�L�X�g�ˑ����[�U�[�C���f�b�N�X
n_uw <- rep(0, length(unique(uw_id)))
uw_index <- list()
context_u <- rep(0, length(n_uw))
context_w1 <- rep(0, length(n_uw))

for(i in 1:hh){
  if(i%%100==0){
    print(i)
  }
  id <- uw_id[user_index[[i]]]
  min_id <- min(id); max_id <- max(id)
  for(j in min_id:max_id){
    uw_index[[j]] <- user_index[[i]][id==j]
    context_u[j] <- user_id[uw_index[[j]]][1]
    context_w1[j] <- context_id[uw_index[[j]]][1]
    n_uw[j] <- length(uw_index[[j]])
  }
}
N_uw <- length(n_uw)

#�R���e�L�X�g�ˑ��A�C�e���C���f�b�N�X
n_vw <- rep(0, length(unique(vw_id)))
vw_index <- list()
context_v <- rep(0, length(n_vw))
context_w2 <- rep(0, length(n_vw))

for(i in 1:item){
  if(i%%100==0){
    print(i)
  }
  id <- vw_id[item_index[[i]]]
  unique_id <- unique(id)
  for(j in 1:length(unique_id)){
    index <- unique_id[j]
    vw_index[[index]] <- item_index[[i]][id==index]
    context_v[index] <- item_id[vw_index[[index]]][1]
    context_w2[index] <- context_id[vw_index[[index]]][1]
    n_vw[index] <- length(vw_index[[index]])
  }
}
N_vw <- length(n_vw)


##�K�w���f���̃C���f�b�N�X
#���[�U�[�C���f�b�N�X
user_index <- list()
user_n <- rep(0, hh)
for(i in 1:hh){
  user_index[[i]] <- which(context_u==i)
  user_n[i] <- length(user_index[[i]])
}
#�A�C�e���C���f�b�N�X
item_index <- list()
item_n <- list()
for(j in 1:item){
  item_index[[j]] <- which(context_v==j)
  item_n[j] <- length(item_index[[j]])
}
#�R���e�L�X�g�C���f�b�N�X
context_index1 <- context_index2 <- list()
context_n1 <- context_n2 <- rep(0, context)
for(j in 1:context){
  context_index1[[j]] <- which(context_w1==j)
  context_index2[[j]] <- which(context_w2==j)
  context_n1[j] <- length(context_index1[[j]])
  context_n2[j] <- length(context_index2[[j]])
}

##�f�[�^�̐ݒ�
#�f���x�N�g���̐����ϐ��̐ݒ�
xx <- t(x) %*% x
inv_xx <- solve(xx)

#���[�U�[�̊K�w���f���̐����ϐ��̐ݒ�
uu <- t(u) %*% u
inv_uu <- solve(uu)

#�A�C�e���̊K�w���f���̐����ϐ��̐ݒ�
vv <- t(v) %*% v
inv_vv <- solve(vv)

#�R���e�L�X�g�̊K�w���f���̐����ϐ��̐ݒ�
ww <- t(w) %*% w
inv_ww <- solve(ww)


##���O���z��ݒ�
#�t�K���}���z�̎��O���z
s0 <- 1
v0 <- 1

#�f����A�x�N�g���̎��O���z
tau1 <- diag(100, ncol(x))
tau_inv1 <- solve(tau1)
mu1 <- rep(0, ncol(x))

#���[�U�[�̊K�w���f���̎��O���z
tau2 <- diag(100, ncol(u))
tau_inv2 <- solve(tau2)
mu2 <- rep(0, ncol(u))
s01 <- 100; v01 <- 1

#�A�C�e���̊K�w���f���̎��O���z
tau3 <- diag(100, ncol(v))
tau_inv3 <- solve(tau3)
mu3 <- rep(0, ncol(v))
s02 <- 1; v02 <- 1
 
#�R���e�L�X�g�̊K�w���f���̎��O���z
Deltabar <- matrix(rep(0, 2*ncol(w)), nrow=ncol(w), ncol=2)   #�K�w���f���̉�A�W���̎��O���z�̕��U
ADelta <- 0.01 * diag(rep(1, ncol(w)))   #�K�w���f���̉�A�W���̎��O���z�̕��U
nu <- 1   #�t�E�B�V���[�g���z�̎��R�x
V <- nu * diag(rep(1, 2)) #�t�E�B�V���[�g���z�̃p�����[�^
s03 <- 1; v03 <- 1


##�ؒf�̈���`
index_y1 <- which(y==1)
index_y0 <- which(y==0)
a <- ifelse(y==0, -100, 0)
b <- ifelse(y==1, 100, 0)


##�p�����[�^�̐^�l
#�f���x�N�g���̉�A�W��
sigma <- 1.0
beta <- solve(t(x) %*% x) %*% t(x) %*% y

#�ϗʌ��ʂ̃p�����[�^
theta_u <- theta_ut   #���[�U�[�̕ϗʌ���
theta_v <- theta_vt   #�A�C�e���̕ϗʌ���
theta_w1 <- theta_wt[, 1]   #�R���e�L�X�g�̕ϗʌ���
theta_w2 <- theta_wt[, 2]
theta_uw <- theta_uwt   #�R���e�L�X�g�ˑ��̃��[�U�[�̕ϗʌ���
theta_vw <- theta_vwt   #�R���e�L�X�g�ˑ��̃A�C�e���̕ϗʌ���

#�ϗʌ��ʂ̃p�����[�^���x�N�g����
theta_u_vec <- theta_u[context_u]
theta_w1_vec <- theta_w1[context_w1]
theta_v_vec <- theta_v[context_v]
theta_w2_vec <- theta_w2[context_w2]

#�K�w���f���̃p�����[�^�𐶐�
tau_u <- tau_ut   #���[�U�[�̊K�w���f���̕W���΍�
alpha_u <- alpha_ut   #���[�U�[�̊K�w���f���̉�A�W��
tau_v <- tau_vt   #�A�C�e���̊K�w���f���̕W���΍�
alpha_v <- alpha_vt   #�A�C�e���̊K�w���f���̉�A�W��
tau_w <- tau_wt   #�R���e�L�X�g�̊K�w���f���̕W���΍�
alpha_w <- alpha_wt   #�R���e�L�X�g�̊K�w���f���̉�A�W��
tau_uw <- tau_uwt   #�R���e�L�X�g�ˑ��̃��[�U�[�o�C�A�X�̕W���΍�
tau_vw <- tau_vwt   #�R���e�L�X�g�ˑ��̃��[�U�[�o�C�A�X�̕W���΍�

#�K�w���f���̉�A���f���̕��ύ\��
u_mu <- as.numeric(u %*% alpha_u)
v_mu <- as.numeric(v %*% alpha_v)
w_mu <- w %*% alpha_w

#���f���̕ϗʌ���
theta_uw <- rep(0, N_uw)
theta_vw <- rep(0, N_vw)
for(i in 1:N_uw){
  theta_uw[i] <- theta_uwt[uw_index[[i]]][1]
}
for(i in 1:N_vw){
  theta_vw[i] <- theta_vwt[vw_index[[i]]][1]
}
theta_vwt0 <- theta_vw; theta_uwt0 <- theta_uw
theta_uw_vec <- theta_uw[uw_id]; theta_vw_vec <- theta_vw[vw_id]


##�����l�̐ݒ�
#�f���x�N�g���̉�A�W��
sigma <- 1.0
beta <- solve(t(x) %*% x) %*% t(x) %*% y 

#�K�w���f���̃p�����[�^�𐶐�
tau_u <- tau_v <- tau_w <- tau_uw <- tau_vw <- 0.75
tau_w <- 0.4
alpha_u <- runif(ncol(u), -0.1, 0.1)   #���[�U�[�̊K�w���f���̉�A�W��
alpha_v <- runif(ncol(v), -0.1, 0.1)   #�A�C�e���̊K�w���f���̉�A�W����
alpha_w <- matrix(runif(ncol(w)*2, -0.1, 0.1), nrow=ncol(w), ncol=2)   #�R���e�L�X�g�̊K�w���f���̉�A�W��

#�K�w���f���̉�A���f���̕��ύ\��
u_mu <- as.numeric(u %*% alpha_u)
v_mu <- as.numeric(v %*% alpha_v)
w_mu <- w %*% alpha_w

#�ϗʌ��ʂ̃p�����[�^
theta_u <- rnorm(hh, 0, tau_u)
theta_v <- rnorm(item, 0, tau_v)
theta_w1 <- rnorm(context, 0, tau_w); theta_w2 <- rnorm(context, 0, tau_w)
theta_uw <- rnorm(N_uw, 0, tau_uw)
theta_vw <- rnorm(N_vw, 0, tau_vw)
theta_uw_vec <- theta_uw[uw_id]
theta_vw_vec <- theta_vw[vw_id]

#�ϗʌ��ʂ̃p�����[�^���x�N�g����
theta_u_vec <- theta_u[context_u]
theta_w1_vec <- theta_w1[context_w1]
theta_v_vec <- theta_v[context_v]
theta_w2_vec <- theta_w2[context_w2]


##�p�����[�^�̊i�[�p�z��
BETA <- matrix(0, nrow=R/keep, ncol=ncol(x))
ALPHA_U <- matrix(0, nrow=R/keep, ncol=ncol(u))
ALPHA_V <- matrix(0, nrow=R/keep, ncol=ncol(v))
ALPHA_W <- matrix(0, nrow=R/keep, ncol=ncol(w)*2)
THETA_UW <- rep(0, N_uw)
THETA_VW <- rep(0, N_vw)
THETA_U <- matrix(0, nrow=R/keep, ncol=hh)
THETA_V <- matrix(0, nrow=R/keep, ncol=item)
THETA_W <- matrix(0, nrow=R/keep, ncol=context*2)
COV <- matrix(0, nrow=R/keep, ncol=length(c(tau_uw, tau_vw, tau_u, tau_v, tau_w)))
rkeep <- c()


##�ΐ��ޓx�̊�l
beta_mu <- as.numeric(x %*% beta)
mu <- beta_mu + theta_uw_vec + theta_vw_vec   #���݌��p�̊��Ғl
prob <- pnorm(mu, 0, sigma)   #�w���m��
LL1 <- sum(y[index_y1]*log(prob[index_y1])) + sum((1-y[index_y0])*log(1-prob[index_y0]))   #�ΐ��ޓx
LLst <- sum(y*log(mean(y)) + (1-y)*log(1-mean(y)))
print(c(LL1, LLst))



####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�ؒf���K���z������݌��p�𐶐�
  beta_mu <- as.numeric(x %*% beta)
  mu <- beta_mu + theta_uw_vec + theta_vw_vec   #���݌��p�̊��Ғl
  U <- as.numeric(rtnorm(mu, sigma, a, b, 1))   #���݌��p�𐶐�
  
  ###�ϗʌ��ʂ̃p�����[�^���T���v�����O
  ##�R���e�L�X�g�ˑ��̃��[�U�[�ϗʌ��ʂ̊��Ғl���T���v�����O
  #�f�[�^�̐ݒ�
  uw_er <- U - beta_mu - theta_vw_vec   #�덷��ݒ�
  
  #�K�w���f���̃p�����[�^
  theta_vec <- theta_u_vec * theta_w1_vec 
  
  #���㕪�z�̃p�����[�^��ݒ�
  uw_mu <- rep(0, N_uw)
  for(i in 1:N_uw){
    uw_mu[i] <- mean(uw_er[uw_index[[i]]])
  }
  weights <- tau_uw^2 / (sigma^2/n_uw + tau_uw^2)    #�d�݌W��
  mu_par <- weights*uw_mu + (1-weights)*theta_vec   #���㕪�z�̕���
  tau <- sqrt(1 / (1/tau_uw^2 + n_uw/sigma^2))
  
  #���K���z��莖�㕪�z���T���v�����O
  theta_uw <- rnorm(N_uw, mu_par, tau)
  theta_uw_vec <- theta_uw[uw_id]
  
  ##�R���e�L�X�g�ˑ��̃��[�U�[�ϗʌ��ʂ̕��U���T���v�����O
  #�t�K���}���z��蕪�U���T���v�����O
  s1 <- s0 + sum((theta_uw - theta_vec)^2)
  v1 <- v0 + N_uw
  tau_uw <- sqrt(1/(rgamma(1, v1/2, s1/2)))
  

  ##�R���e�L�X�g�ˑ��̃A�C�e���ϗʌ��ʂ��T���v�����O
  #�f�[�^�̐ݒ�
  vw_er <- U - beta_mu - theta_uw_vec   #�덷��ݒ�
  
  #�K�w���f���̃p�����[�^
  theta_vec <- theta_v_vec * theta_w2_vec 
  
  #���㕪�z�̃p�����[�^��ݒ�
  vw_mu <- rep(0, N_vw)
  for(i in 1:N_vw){
    vw_mu[i] <- mean(vw_er[vw_index[[i]]])
  }
  weights <- tau_vw^2 / (sigma/n_vw + tau_vw^2)   #�d�݌W��
  mu_par <- weights*vw_mu + (1-weights)*theta_vec   #���㕪�z�̕���
  tau <- sqrt(1 / (1/tau_vw^2 + n_vw/sigma^2))
  
  #���K���z��莖�㕪�z���T���v�����O
  theta_vw <- rnorm(N_vw, mu_par, tau)
  theta_vw_vec <- theta_vw[vw_id]
  
  ##�R���e�L�X�g�ˑ��̃��[�U�[�ϗʌ��ʂ̕��U���T���v�����O
  #�t�K���}���z��蕪�U���T���v�����O
  s1 <- s0 + sum((theta_vw - theta_vec)^2)
  v1 <- v0 + N_vw
  tau_vw <- sqrt(1/(rgamma(1, v1/2, s1/2)))

  
  ##���[�U�[�ϗʌ��ʂ��T���v�����O
  #���[�U�[���ƂɎ��㕪�z�̃p�����[�^��ݒ�
  inv_tau_u <- 1/tau_u^2
  mu_par <- rep(0, hh)
  sigma_par <- rep(0, hh)
  
  for(i in 1:hh){
    index <- context_w1[user_index[[i]]]
    X <- theta_w1[index]
    Xy <- (t(X) %*% theta_uw[user_index[[i]]])
    XXV <- (t(X) %*% X) + inv_tau_u
    inv_XXV <- 1/XXV
    sigma_par[i] <- tau_uw^2 * inv_XXV
    mu_par[i] <- inv_XXV %*% (Xy + inv_tau_u %*% u_mu[i])
  }
  
  #���K���z���玖�㕪�z���T���v�����O
  theta_u <- rnorm(hh, mu_par, sqrt(sigma_par))
  
  
  ##�A�C�e���ϗʌ��ʂ𐄒�
  #���[�U�[���ƂɎ��㕪�z�̃p�����[�^��ݒ�
  inv_tau_v <- 1/tau_v^2
  mu_par <- rep(0, item)
  sigma_par <- rep(0, item)
  
  for(i in 1:item){
    index <- context_w2[item_index[[i]]]
    X <- theta_w2[index]
    Xy <- (t(X) %*% theta_vw[item_index[[i]]])
    XXV <- (t(X) %*% X) + inv_tau_v
    inv_XXV <- 1/XXV
    sigma_par[i] <- tau_vw^2 * inv_XXV
    mu_par[i] <- inv_XXV %*% (Xy + inv_tau_v %*% v_mu[i])
  }
  #���K���z���玖�㕪�z���T���v�����O
  theta_v <- rnorm(item, mu_par, sqrt(sigma_par))
  
  
  ##�R���e�L�X�g�ϗʌ��ʂ��T���v�����O
  #�R���e�L�X�g���ƂɎ��㕪�z�̃p�����[�^��ݒ�
  inv_tau_w <- 1/tau_w^2
  mu_par <- matrix(0, nrow=context, ncol=2)
  sigma_par <- matrix(0, nrow=context, ncol=2)
  
  for(i in 1:context){
    index1 <- context_u[context_index1[[i]]]; index2 <- context_v[context_index2[[i]]]
    X1 <- theta_u[index1]; X2 <- theta_v[index2]
    Xy1 <- (t(X1) %*% theta_uw[context_index1[[i]]])
    Xy2 <- (t(X2) %*% theta_vw[context_index2[[i]]])
    XXV1 <- (t(X1) %*% X1) + inv_tau_w
    XXV2 <- (t(X2) %*% X2) + inv_tau_w
    inv_XXV1 <- 1/XXV1; inv_XXV2 <- 1/XXV2
    sigma_par[i, 1] <- tau_uw^2 * inv_XXV1
    sigma_par[i, 2] <- tau_vw^2 * inv_XXV2
    mu_par[i, 1] <- inv_XXV1 %*% (Xy1 + inv_tau_w %*% w_mu[i, 1])
    mu_par[i, 2] <- inv_XXV2 %*% (Xy2 + inv_tau_w %*% w_mu[i, 2])
  }
  
  #���K���z���玖�㕪�z���T���v�����O
  theta_w1 <- rnorm(context, mu_par[, 1], sqrt(sigma_par[, 1]))
  theta_w2 <- rnorm(context, mu_par[, 2], sqrt(sigma_par[, 2]))
  theta_w <- cbind(theta_w1, theta_w2)
  
  
  ##�p�����[�^���ϑ��x�N�g���̃��R�[�h���ɕϊ�
  theta_u_vec <- theta_u[context_u]
  theta_w1_vec <- theta_w1[context_w1]
  theta_v_vec <- theta_v[context_v]
  theta_w2_vec <- theta_w2[context_w2]
  
  
  ###�f����A���f���ƊK�w���f���̃p�����[�^���T���v�����O
  ##��A�p�����[�^���T���v�����O
  #��A�x�N�g���̃p�����[�^
  u_er <- U - theta_uw_vec - theta_vw_vec   #�����ϐ��̐ݒ�
  inv_XXV <- solve(xx + tau_inv1)
  Xy <- t(x) %*% u_er
  mu_par <- inv_XXV %*% (Xy + tau_inv1 %*% mu1)
  
  #���K���z�����A�x�N�g�����T���v�����O
  beta <- mvrnorm(1, mu_par, sigma^2*inv_XXV)
  beta_mu <- as.numeric(x %*% beta)   #�f���x�N�g���̕��ύ\��
  
  
  ##���[�U�[�̊K�w���f���̃p�����[�^���T���v�����O
  ##��A�p�����[�^���T���v�����O
  #��A�x�N�g���̃p�����[�^
  inv_XXV <- solve(uu + tau_inv2)
  Xy <- t(u) %*% theta_u
  mu_par <- inv_XXV %*% (Xy + tau_inv2 %*% mu2)
  
  #���K���z�����A�x�N�g�����T���v�����O
  alpha_u <- mvrnorm(1, mu_par, tau_u^2*inv_XXV)
  u_mu <- as.numeric(u %*% alpha_u)   #�f���x�N�g���̕��ύ\��
  
  ##���[�U�[�ϗʌ��ʂ̕��U���T���v�����O
  #�t�K���}���z��蕪�U���T���v�����O
  s1 <- s01 + sum((theta_u - u_mu)^2)
  v1 <- v01 + hh
  tau_u <- sqrt(1/(rgamma(1, v1/2, s1/2)))
  

  ##�A�C�e���̊K�w���f���̃p�����[�^���T���v�����O
  ##��A�p�����[�^���T���v�����O
  #��A�x�N�g���̃p�����[�^
  inv_XXV <- solve(vv + tau_inv3)
  Xy <- t(v) %*% theta_v
  mu_par <- inv_XXV %*% (Xy + tau_inv3 %*% mu3)
  
  #���K���z�����A�x�N�g�����T���v�����O
  alpha_v <- mvrnorm(1, mu_par, tau_v^2*inv_XXV)
  v_mu <- as.numeric(v %*% alpha_v)   #�f���x�N�g���̕��ύ\��
  
  ##�A�C�e���ϗʌ��ʂ̕��U���T���v�����O
  #�t�K���}���z��蕪�U���T���v�����O
  s1 <- s02 + sum((theta_v - v_mu)^2)
  v1 <- v02 + item
  tau_v <- sqrt(1/(rgamma(1, v1/2, s1/2)))
  
  
  ##�R���e�L�X�g�̊K�w���f���̃p�����[�^���T���v�����O
  #���ϗʉ�A���f�������A�x�N�g�����T���v�����O
  out <- rmultireg(theta_w, w, Deltabar, ADelta, nu, V)
  alpha_w <- out$B
  w_mu <- w %*% alpha_w
  
  ##�T���v�����O���ʂ�ۑ��ƌ��ʂ̕\��
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    BETA[mkeep, ] <- beta
    ALPHA_U[mkeep, ] <- alpha_u
    ALPHA_V[mkeep, ] <- alpha_v
    ALPHA_W[mkeep, ] <- as.numeric(alpha_w)
    THETA_U[mkeep, ] <- theta_u
    THETA_V[mkeep, ] <- theta_v
    THETA_W[mkeep, ] <- as.numeric(theta_w)
    COV[mkeep, ] <- c(tau_uw, tau_vw, tau_u, tau_v, tau_w)
  }
  
  #�R���e�L�X�g�ˑ��ϗʌ��ʂ̓o�[���C�����Ԃ𒴂�����i�[����
  if(rp%%keep==0 & rp >= burnin){
    rkeep <- c(rkeep, rp)
    THETA_UW <- THETA_UW + theta_uw
    THETA_VW <- THETA_VW + theta_vw
  }
    
  if(rp%%disp==0){
    #�ΐ��ޓx�𐄒�
    Mu <- beta_mu + theta_uw_vec + theta_vw_vec   #���S�f�[�^�̕��ύ\��
    prob <- pnorm(Mu, 0, sigma)   #�w���m��
    LL <- sum(y[index_y1]*log(prob[index_y1])) + sum((1-y[index_y0])*log(1-prob[index_y0]))   #�ΐ��ޓx
    
    #�T���v�����O���ʂ̕\��
    print(rp)
    print(c(LL, LL1, LLst))
    print(round(c(tau_u, tau_v, tau_w, tau_uw, tau_vw), 3))
    print(round(rbind(beta, betat), 3))
  }
}


matplot(COV, type="l")

tau_u
tau_v
tau_uw
tau_vw
mean(prob[y==1])
mean((1-prob)[y==0])
563474.1 

round(cbind(theta_uw, theta_uwt0, n_uw), 3)
round(cbind(theta_vw, theta_vwt0, n_vw), 3)
round(cbind(theta_u, theta_ut), 3)
round(cbind(theta_v, theta_vt), 3)
round(cbind(theta_w, theta_wt), 3)

