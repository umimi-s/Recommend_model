#####���`��A�x�[�X���݈��q���f��#####
library(MASS)
library(Matrix)
library(matrixStats)
library(data.table)
library(bayesm)
library(MCMCpack)
library(condMVNorm)
library(extraDistr)
library(reshape2)
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
k <- 10   #��ꐔ
hh <- 5000   #���[�U�[��
item <- 2000   #�A�C�e����

##ID�̐ݒ�
user_id0 <- rep(1:hh, rep(item, hh))
item_id0 <- rep(1:item, hh)


##�f���x�N�g���𐶐�
k1 <- 2; k2 <- 3; k3 <- 4
x1 <- matrix(runif(hh*item*k1, 0, 1), nrow=hh*item, ncol=k1)
x2 <- matrix(0, nrow=hh*item, ncol=k2)
for(j in 1:k2){
  pr <- runif(1, 0.25, 0.55)
  x2[, j] <- rbinom(hh*item, 1, pr)
}
x3 <- rmnom(hh*item, 1, runif(k3, 0.2, 1.25)); x3 <- x3[, -which.min(colSums(x3))]
x0 <- cbind(x1, x2, x3)   #�f�[�^������


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


##�����ϐ����Ó��ɂȂ�܂Ńp�����[�^�̐������J��Ԃ�
for(rp in 1:1000){
  print(rp)
  
  ##�f���x�N�g���̉�A�W���𐶐�
  beta <- rep(0, ncol(x0))
  for(j in 1:ncol(x0)){
    beta[j] <- runif(1, -0.6, 1.6)
  }
  betat <- beta
  
  ##�K�w���f���̃p�����[�^�𐶐�
  ##���[�U�[�x�[�X�̊K�w���f���̃p�����[�^
  #���U�����U�s���ݒ�
  sigma_ut <- sigma_u <- 0.4
  Cov_ut <- Cov_u <- covmatrix(k, corrM(k, -0.6, 0.8, 0.05, 0.2), 0.01, 0.25)$covariance
  
  #��A�W����ݒ�
  alpha_u <- matrix(0, nrow=ncol(u), ncol=k+1)
  for(j in 1:ncol(u)){
    if(j==1){
      alpha_u[j, ] <- runif(k+1, -0.55, 1.3)
    } else {
      alpha_u[j, ] <- runif(k+1, -0.4, 0.5)
    }
  }
  alpha_ut <- alpha_u
  
  #���ϗʉ�A���f�����烆�[�U�[�ʂ̉�A�p�����[�^�𐶐�
  theta_u <- u %*% alpha_u + cbind(rnorm(hh, 0, sigma_u), mvrnorm(hh, rep(0, k), Cov_u))
  theta_ut1 <- theta_u1 <- theta_u[, 1]   #�����_�����ʂ̃p�����[�^
  theta_ut2 <- theta_u2 <- theta_u[, -1]   #�s�񕪉��̃p�����[�^
  
  
  ##�A�C�e���x�[�X�̊K�w���f���̃p�����[�^
  #���U�����U�s���ݒ�
  sigma_vt <- sigma_v <- 0.4
  Cov_vt <- Cov_v <- covmatrix(k, corrM(k, -0.6, 0.8, 0.05, 0.2), 0.01, 0.25)$covariance
  
  #��A�W����ݒ�
  alpha_v <- matrix(0, nrow=ncol(v), ncol=k+1)
  for(j in 1:ncol(v)){
    if(j==1){
      alpha_v[j, ] <- runif(k+1, -0.55, 1.3)
    } else {
      alpha_v[j, ] <- runif(k+1, -0.4, 0.5)
    }
  }
  alpha_vt <- alpha_v
  
  #���ϗʉ�A���f������A�C�e���ʂ̉�A�p�����[�^�𐶐�
  theta_v <- v %*% alpha_v + cbind(rnorm(item, 0, sigma_v), mvrnorm(item, rep(0, k), Cov_v))
  theta_vt1 <- theta_v1 <- theta_v[, 1]   #�����_�����ʂ̃p�����[�^
  theta_vt2 <- theta_v2 <- theta_v[, -1]   #�s�񕪉��̃p�����[�^
  
  
  ##LRBLF���f���̉����ϐ��𐶐�
  #���f���̊ϑ��덷
  sigmat <- sigma <- 0.75   
  
  #���f���̕��ύ\�����牞���ϐ��𐶐�
  mu <- x0 %*% beta + theta_u1[user_id0] + theta_v1[item_id0] + as.numeric(t(theta_u2 %*% t(theta_v2)))   #���ύ\��
  y0 <- rnorm(hh*item, mu, sigma)
  
  #�����ϐ���break����
  if(mean(y0) > 4.5 & mean(y0) < 6.5 & min(y0) > -7.5 & max(y0) < 17.5) break
}

#���������X�R�A��]���f�[�^�ɕϊ�
y0_censor <- ifelse(y0 < 1, 1, ifelse(y0 > 10, 10, y0)) 
y_full <- round(y0_censor, 0)   #�X�R�A���ۂ߂�


##�����x�N�g���𐶐�
#�����L���̃x�[�^���z�̃p�����[�^��ݒ�
beta1 <- rbeta(hh, 8.5, 10.0)   #���[�U-�w���m��
beta2 <- rbeta(item, 6.5, 8.0)   #�A�C�e���w���m��

#����������w���f�[�^�𐶐�
Z <- matrix(0, nrow=hh, ncol=item)
for(j in 1:item){
  deficit <- rbinom(hh, 1, beta1 * beta2[j])
  Z[, j] <- deficit   #��������
}

#�����C���f�b�N�X
z_vec <- as.numeric(t(Z))
index_z1 <- which(z_vec==1)
index_z0 <- which(z_vec==0)
N <- length(index_z1)

#�����x�N�g���ɉ����ăf�[�^�𒊏o
user_id <- user_id0[index_z1]
item_id <- item_id0[index_z1]
x <- x0[index_z1, ]
y <- y_full[index_z1]
n1 <- plyr::count(user_id)$freq
n2 <- plyr::count(item_id)$freq


#�������������ϐ��̃q�X�g�O����
hist(y0, col="grey", xlab="�X�R�A", main="���[�U�[�~�A�C�e���̃X�R�A���z")   #���f�[�^
hist(y_full, col="grey", xlab="�X�R�A", main="���[�U�[�~�A�C�e���̃X�R�A���z")   #���S�f�[�^�̃X�R�A���z
hist(y, col="grey", xlab="�X�R�A", main="���[�U�[�~�A�C�e���̃X�R�A���z")   #�w���f�[�^�̃X�R�A���z


####�����e�J����EM�A���S���Y����LRBLF���f���𐄒�####
##�A���S���Y���̐ݒ�
LL1 <- -100000000   #�ΐ��ޓx�̏����l
tol <- 0.25
iter <- 1
dl <- 100
L <- 500   #�����e�J�����T���v�����O��

##�����l�̐ݒ�
#���f���p�����[�^�̏����l
beta <- rep(0, ncol(x))
beta_mu <- x %*% beta   #�Œ���ʂ̊��Ғl   
sigma <- 0.5

#���[�U�[�x�[�X�̃p�����[�^�̏����l
sigma_u <- 0.2 
Cov_u <- 0.1 * diag(k)
inv_Cov_u <- solve(Cov_u)
alpha_u <- matrix(0, nrow=ncol(u), ncol=k+1)
theta_mu1 <- u %*% alpha_u
theta_u1 <- theta_mu11 <- theta_mu1[, 1]
theta_mu12 <- theta_mu1[, -1]
theta_u2 <- theta_mu12 + mvrnorm(hh, rep(0, k), Cov_u)

#�A�C�e���x�[�X�̃p�����[�^�̏����l
sigma_v <- 0.2
Cov_v <- 0.1 * diag(k)
inv_Cov_v <- solve(Cov_v)
alpha_v <- matrix(0, nrow=ncol(v), ncol=k+1)
theta_mu2 <- v %*% alpha_v
theta_v1 <- theta_mu21 <- theta_mu2[, 1]
theta_mu22 <- t(theta_mu2[, -1])
theta_v2 <- theta_mu22 + t(mvrnorm(item, rep(0, k), Cov_v))

#�s�񕪉��̏����l
uv <- as.numeric(t(theta_u2 %*% theta_v2))[index_z1]


##�f�[�^�̐ݒ�
#�C���f�b�N�X�̍쐬
user_list <- item_list <- list()
for(i in 1:hh){
  user_list[[i]] <- which(user_id==i)
}
for(j in 1:item){
  item_list[[j]] <- which(item_id==j)
}
#�萔�̐ݒ�
inv_xx <- solve(t(x) %*% x)
inv_uu <- solve(t(u) %*% u)
inv_vv <- solve(t(v) %*% v)

#�ΐ��ޓx�̏����l
Mu <- beta_mu + theta_u1[user_id] + theta_v1[item_id] + uv   #���S�f�[�^�̕��ύ\��
LL <- sum(dnorm(y, Mu, sigma, log=TRUE))   #���S�f�[�^�̑ΐ��ޓx���X�V
print(LL)


####�����e�J����EM�A���S���Y�����p�����[�^�𐄒�####
while(dl > 0){   #dl��tol�ȏ�Ȃ�J��Ԃ�
  
  ###�����e�J����E�X�e�b�v�Ő��ݕϐ����T���v�����O
  ##���[�U�[�̃����_�����ʂ��T���v�����O
  #�f�[�^�̐ݒ�
  u_er <- as.numeric(y - beta_mu - theta_v1[item_id] - uv)   #���[�U�[�̃����_�����ʂ̌덷
  
  #���㕪�z�̃p�����[�^��ݒ�
  u_mu <- rep(0, hh)
  for(i in 1:hh){
    u_mu[i] <- mean(u_er[user_list[[i]]])
  }
  weights <- sigma_u^2 / (sigma^2/n1 + sigma_u^2)   #�d�݌W��
  mu_par <- weights*u_mu + (1-weights)*theta_mu11   #���㕪�z�̕���
  
  
  #���K���z��莖�㕪�z���T���v�����O
  theta_u_data <- matrix(rnorm(hh*L, mu_par, sqrt(1 / (1/sigma_u^2 + n1/sigma^2))), nrow=hh, ncol=L)
  theta_u1 <- rowMeans(theta_u_data)
  u1_vars <- rowVars(theta_u_data)
  
  
  ##�A�C�e���̃����_�����ʂ��T���v�����O
  #�f�[�^�̐ݒ�
  i_er <- as.numeric(y - beta_mu - theta_u1[user_id] - uv)
  
  #���㕪�z�̃p�����[�^
  i_mu <- rep(0, item)
  for(j in 1:item){
    i_mu[j] <- mean(i_er[item_list[[j]]])
  }
  weights <- sigma_v^2 / (sigma^2/n2 + sigma_v^2)   #�d�݌W��
  mu_par <- weights*i_mu + (1-weights)*theta_mu21   #���㕪�z�̕���
  
  #���K���z��莖�㕪�z���T���v�����O
  theta_v1_data <- matrix(rnorm(item*L, mu_par, sqrt(1 / (1/sigma_v^2 + n2/sigma^2))), nrow=item, ncol=L)
  theta_v1 <- rowMeans(theta_v1_data)
  v1_vars <- rowVars(theta_v1_data)
  
  
  ##���[�U�[�����s��̃p�����[�^���T���v�����O
  #�f�[�^�̐ݒ�
  theta_u_vec <- theta_u1[user_id]; theta_v_vec <- theta_v1[item_id]
  uv_er <- as.numeric(y - beta_mu - theta_u_vec - theta_v_vec)
  theta_v2_T <- t(theta_v2)
  theta_u2 <- matrix(0, nrow=hh, ncol=k)
  u2_vars <- matrix(0, nrow=k, ncol=k)
  
  #���[�U�[���Ƃɓ����x�N�g�����T���v�����O
  for(i in 1:hh){
    
    #�����x�N�g���̎��㕪�z�̃p�����[�^
    index <- item_id[user_list[[i]]]   #�A�C�e���C���f�b�N�X
    Xy <- t(theta_v2_T[index, , drop=FALSE]) %*% uv_er[user_list[[i]]]
    XXV <- (t(theta_v2_T[index, , drop=FALSE]) %*% theta_v2_T[index, , drop=FALSE]) + inv_Cov_u
    inv_XXV <- solve(XXV)
    mu <- inv_XXV %*% (Xy + inv_Cov_u %*% theta_mu12[i, ])   #���㕪�z�̕���
    
    #���ϗʐ��K���z���烆�[�U�[�����x�N�g�����T���v�����O
    theta_u2_data <- mvrnorm(L, mu, sigma^2*inv_XXV)
    theta_u2[i, ] <- colMeans(theta_u2_data)   #�����e�J��������
    u2_vars <- u2_vars + var(theta_u2_data)
  }
  
  
  ##�A�C�e�������s��̃p�����[�^���T���v�����O
  #�A�C�e�����Ƃɓ����x�N�g�����T���v�����O
  theta_v2 <- matrix(0, nrow=k, ncol=item)
  v2_vars <- matrix(0, nrow=k, ncol=k)
  for(j in 1:item){
    
    #�����x�N�g���̎��㕪�z�̃p�����[�^
    index <- user_id[item_list[[j]]]   #�A�C�e���C���f�b�N�X
    Xy <- t(theta_u2[index, , drop=FALSE]) %*% uv_er[item_list[[j]]]
    XXV <- (t(theta_u2[index, , drop=FALSE]) %*% theta_u2[index, , drop=FALSE]) + inv_Cov_v
    inv_XXV <- solve(XXV)
    mu <- inv_XXV %*% (Xy + inv_Cov_v %*% theta_mu22[, j])   #���㕪�z�̕���
    
    #���ϗʐ��K���z����A�C�e�������x�N�g�����T���v�����O
    theta_v2_data <- mvrnorm(L, mu, sigma^2*inv_XXV)
    theta_v2[, j] <- colMeans(theta_v2_data)   #�����e�J��������
    v2_vars <- v2_vars + var(theta_v2_data)
  }
  
  
  ###M�X�e�b�v�Ŋ��S�f�[�^�̖ޓx���ő剻
  #�s�񕪉��̃p�����[�^
  uv <- as.numeric(t(theta_u2 %*% theta_v2))[index_z1]
  
  ##�f���x�N�g���̃p�����[�^���X�V
  y_er <- y - theta_u_vec - theta_v_vec - uv   #�����ϐ���ݒ�
  beta <- inv_xx %*% t(x) %*% y_er   #�ŏ����@�őf���x�N�g�����X�V
  beta_mu <- x %*% beta   #�f���x�N�g���̕��ύ\��
  
  ##�ϑ����f���̌덷�p�����[�^���X�V
  er <- y - beta_mu - theta_u_vec - theta_v_vec - uv
  sigma <- sd(er)
  
  
  ##�K�w���f���̃p�����[�^���X�V
  #���[�U�[�̃����_�����ʂ̊K�w���f���̃p�����[�^���X�V
  alpha_u[, 1] <- inv_uu %*% t(u) %*% theta_u1
  theta_mu11 <- as.numeric(u %*% alpha_u[, 1])
  sigma_u <- sqrt((sum(u1_vars) + sum((theta_u1 - theta_mu11)^2)) / hh)
  
  
  #�A�C�e���̃����_�����ʂ̊K�w���f���̃p�����[�^���X�V
  alpha_v[, 1] <- inv_vv %*% t(v) %*% theta_v1
  theta_mu21 <- as.numeric(v %*% alpha_v[, 1])
  sigma_v <- sqrt((sum(v1_vars) + sum((theta_v1 - theta_mu21)^2)) / item)
  
  #���[�U�[�����s��̊K�w���f���̃p�����[�^���X�V
  alpha_u[, -1] <- inv_uu %*% t(u) %*% theta_u2
  theta_mu12 <- u %*% alpha_u[, -1]
  Cov_u <- (u2_vars + t(theta_u2 - theta_mu12) %*% (theta_u2 - theta_mu12)) / hh
  inv_Cov_u
  
  #�A�C�e�������s��̊K�w���f���̃p�����[�^���X�V
  alpha_v[, -1] <- inv_vv %*% t(v) %*% t(theta_v2)
  theta_mu22 <- t(v %*% alpha_v[, -1])
  Cov_v <- (v2_vars + (theta_v2 - theta_mu22) %*% t(theta_v2 - theta_mu22)) / item
  inv_Cov_v <- solve(Cov_v)
  
  ##�A���S���Y���̎�������
  Mu <- beta_mu + theta_u_vec + theta_v_vec + uv   #���S�f�[�^�̕��ύ\��
  LL <- sum(dnorm(y, Mu, sigma, log=TRUE))   #���S�f�[�^�̑ΐ��ޓx���X�V
  iter <- iter + 1
  dl <- LL - LL1
  LL1 <- LL
  print(LL)
}

####���茋�ʂ̊m�F�ƓK���x####
##��r�Ώۃ��f���̑ΐ��ޓx
#�ŏ����@�ł̑ΐ��ޓx
X <- cbind(1, x, u[user_id, -1], v[item_id, -1])
b <- solve(t(X) %*% X) %*% t(X) %*% y
tau <- sd(y - X %*% b)
LLsq <- sum(dnorm(y, X %*% b, tau, log=TRUE))

#�^�l�ł̑ΐ��ޓx
uvt <- as.numeric(t(theta_ut2 %*% t(theta_vt2)))[index_z1]
beta_mut <- x %*% betat
Mut <- beta_mut + theta_ut1[user_id] + theta_vt1[item_id] + uvt   #���S�f�[�^�̕��ύ\��
LLt <- sum(dnorm(y, Mut, sd(y-Mut), log=TRUE))

#�w�K�f�[�^�ɑ΂���ΐ��ޓx�̔�r
c(LL, LLt, LLsq)


##�����f�[�^(�e�X�g�f�[�^)�ɑ΂���ΐ��ޓx�Ɠ��덷���v�Z
#���茋�ʂł̕��ύ\��
beta_mu <- x0 %*% beta
uv <- as.numeric(t(theta_u2 %*% theta_v2))
Mu <- as.numeric(beta_mu + theta_u1[user_id0] + theta_v1[item_id0] + uv)
sigmaf <- sd(y_full[index_z0] - Mu[index_z0])

#�^�l�ł̕��ύ\��
beta_mut <- x0 %*% betat
uvt <- as.numeric(t(theta_ut2 %*% t(theta_vt2)))
Mut <- as.numeric(beta_mut + theta_ut1[user_id0] + theta_vt1[item_id0] + uvt)   #���S�f�[�^�̕��ύ\��

#�ŏ����@�ł̕��ύ\��
X <- cbind(1, x0, u[user_id0, -1], v[item_id0, -1])
Mu_sq <- X %*% b

#�e�X�g�f�[�^�ɑ΂���ΐ��ޓx
sum(dnorm(y_full[index_z0], Mu[index_z0], sigmaf, log=TRUE))   #���茋�ʂ̑ΐ��ޓx
sum(dnorm(y_full[index_z0], Mut[index_z0], sigmat, log=TRUE))   #�^�l�̑ΐ��ޓx
sum(dnorm(y_full[index_z0], Mu_sq[index_z0], tau, log=TRUE))   #�ŏ����@�̑ΐ��ޓx

#�e�X�g�f�[�^�ɑ΂�����덷
sum((y_full[index_z0] - Mu[index_z0])^2)   #���茋�ʂ̓��덷
sum((y_full[index_z0] - Mut[index_z0])^2)   #�^�l�̓��덷
sum((y_full[index_z0] - Mu_sq[index_z0])^2)   #�ŏ����@�̓��덷

#���ʂ��r
result <- round(data.table(z_vec, y_full, Mu, Mut, Mu_sq), 3)
colnames(result) <- c("z_vec", "y_full", "Mu", "Mut", "Mu_sq")