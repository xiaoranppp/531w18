## ----opts,include=FALSE,cache=FALSE--------------------------------------
options(
  keep.source=TRUE,
  encoding="UTF-8"
)

## ----chi_squared---------------------------------------------------------
qchisq(0.95,df=1)

## ----read_data-----------------------------------------------------------
dat <- read.table(file="huron_depth.csv",sep=",",header=TRUE)
dat$Date <- strptime(dat$Date,"%m/%d/%Y")
dat$year <- as.numeric(format(dat$Date, format="%Y"))
dat$month <- as.numeric(format(dat$Date, format="%m"))
head(dat)

## ----select_annual-------------------------------------------------------
dat <- subset(dat,month==1)
huron_depth <- dat$Average
year <- dat$year
plot(huron_depth~year,type="l")

## ----aic_table-----------------------------------------------------------
aic_table <- function(data,P,Q){
  table <- matrix(NA,(P+1),(Q+1))
  for(p in 0:P) {
    for(q in 0:Q) {
       table[p+1,q+1] <- arima(data,order=c(p,0,q))$aic
    }
  }
  dimnames(table) <- list(paste("<b> AR",0:P, "</b>", sep=""),paste("MA",0:Q,sep=""))
  table
}
huron_aic_table <- aic_table(huron_depth,4,5)
require(knitr)
kable(huron_aic_table,digits=2)

## ----arma21fit-----------------------------------------------------------
huron_arma21 <- arima(huron_depth,order=c(2,0,1))
huron_arma21

## ----huron_roots---------------------------------------------------------
AR_roots <- polyroot(c(1,-coef(huron_arma21)[c("ar1","ar2")]))
AR_roots

## ----huron_profile-------------------------------------------------------
K <- 500
ma1 <- seq(from=0.2,to=1.1,length=K)
profile_loglik <- rep(NA,K)
for(k in 1:K){
   profile_loglik[k] <- logLik(arima(huron_depth,order=c(2,0,1),
      fixed=c(NA,NA,ma1[k],NA)))
}
plot(profile_loglik~ma1,ty="l")

## ----simA----------------------------------------------------------------
set.seed(57892330)
J <- 1000
params <- coef(huron_arma21)
ar <- params[grep("^ar",names(params))]
ma <- params[grep("^ma",names(params))]
intercept <- params["intercept"]
sigma <- sqrt(huron_arma21$sigma2)
theta <- matrix(NA,nrow=J,ncol=length(params),dimnames=list(NULL,names(params)))
for(j in 1:J){
   Y_j <- arima.sim(
      list(ar=ar,ma=ma),
      n=length(huron_depth),
      sd=sigma
   )+intercept
   theta[j,] <- coef(arima(Y_j,order=c(2,0,1)))
}
hist(theta[,"ma1"],freq=FALSE) 

## ----density-------------------------------------------------------------
plot(density(theta[,"ma1"],bw=0.05))

## ----range---------------------------------------------------------------
range(theta[,"ma1"])

## ----parallel-setup,cache=FALSE------------------------------------------
require(doParallel)
registerDoParallel()

## ----simB----------------------------------------------------------------
J <- 1000
huron_ar1 <- arima(huron_depth,order=c(1,0,0))
params <- coef(huron_ar1)
ar <- params[grep("^ar",names(params))]
intercept <- params["intercept"]
sigma <- sqrt(huron_ar1$sigma2)
t1 <- system.time(
  huron_sim <- foreach(j=1:J) %dopar% {
     Y_j <- arima.sim(list(ar=ar),n=length(huron_depth),sd=sigma)+intercept
     try(coef(arima(Y_j,order=c(2,0,1))))
  }
) 

## ----out, cache=FALSE----------------------------------------------------
sum(sapply(huron_sim, function(x) inherits(x,"try-error"))) 

## ----histB, cache=FALSE--------------------------------------------------
ma1 <- unlist(lapply(huron_sim,function(x) if(!inherits(x,"try-error"))x["ma1"] else NULL ))
hist(ma1,breaks=50)  

## ----repeated_aic,echo=FALSE---------------------------------------------
require(knitr)
kable(huron_aic_table,digits=2)

