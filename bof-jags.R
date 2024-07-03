# bof msom jags model

# first try a single species model

library(R2jags)
library(rjags)
library(foreign)
library(dclone)      # built-in functionality for parallel MCMC with jags via jags.parfit()
library(viridis)
library(fields)

# prepare data
RIWH3d_01 <- RIWH3d
I <- which(RIWH3d_01>1)
RIWH3d_01[I] = 1

dets <- RIWH3d_01[, 2:(max_survs+1),]
bft <- bft3d[, 2:(max_survs+1),]
jday <- jday3d[, 2:(max_survs+1),]
eff <- effort3d[, 2:(max_survs+1),]

# count seasons, sites, years, visits
numseasons <- 1
n.season <- numseasons
n.site <- dim(dets)[1]
n.year <- dim(dets)[3]/numseasons
n.visit = dim(dets)[2]

# Standardize covariates (mean = 0, sd = 1, all NA converted to 0)
bft.st <- (bft - mean(bft, na.rm = T)) / sd(bft, na.rm = T)
bft.st[is.na(bft.st)] <- 0
jday.st <- (jday - mean(jday, na.rm = T)) / sd(jday, na.rm = T)
jday.st[is.na(jday.st)] <- 0
eff.st <- (eff - mean(eff, na.rm = T)) / sd(eff, na.rm = T)
eff.st[is.na(eff.st)] <- 0

y.array <- array(dim = c(n.site, n.visit, n.season, n.year))
#cov.array <- array(dim = c(n.site, n.season, n.year))
dets4d <- array(dim = dim(y.array), data = as.vector(dets))
bft4d <- array(dim = dim(y.array), data = as.vector(bft.st))
jday4d <- array(dim = dim(y.array), data = as.vector(jday.st))
eff4d <- array(dim = dim(y.array), data = as.vector(eff.st))


############## JAGS Model & Run #####################

jags.data <- list(y = dets4d,
                       bft = bft4d,
                       jday = jday4d,
                       eff = eff4d,
                       n.site = n.site,
                       n.season = n.season,
                       n.visit = n.visit,
                       n.year = n.year
)

psi.naive <- table(apply(dets4d, c(1,3,4), max, na.rm = T))[3] / (table(apply(dets4d, c(1,3,4), max, na.rm = T))[3] + table(apply(dets4d, c(1,3,4), max, na.rm = T))[2])
z.naive <- apply(dets4d, MARGIN = c(1,3,4), max, na.rm = T)
z.naive[z.naive == "-Inf"] <- rbinom(n = sum(z.naive == "-Inf"), size = 1, prob = psi.naive)
inits <- list(Z = z.naive)

##### Model specification #####

whale.mod <- function() {         
  
  ## Priors
  
  # Priors on annual random effects
  mu.b.0 ~ dnorm(0,0.1)
  tau.b.0 ~ dgamma(0.1, 0.1)
  
  mu.a.0 ~ dnorm(0,0.1)
  tau.a.0 ~ dgamma(0.1, 0.1)
  
  mu.a.bft ~ dnorm(0, 0.1)
  tau.a.bft ~ dgamma(0.1, 0.1)
  
  mu.a.jday ~ dnorm(0,0.1)
  tau.a.jday ~ dgamma(0.1, 0.1)
  
  mu.a.eff ~ dnorm(0, 0.1)
  tau.a.eff ~ dgamma(0.1, 0.1)
  
  mu.g.0 ~ dnorm(0, 0.1)
  tau.g.0 ~ dgamma(0.1, 0.1)
  
  mu.e.0 ~ dnorm(0, 0.1)
  tau.e.0 ~ dgamma(0.1, 0.1)
  
  ### Hiearchically loop over each year
  for (t in 1:n.year) {
    
    # Year-specific hierarchical effects
    b.0[t] ~ dnorm(mu.b.0, tau.b.0)
    a.0[t] ~ dnorm(mu.a.0, tau.a.0)
    a.jday[t] ~ dnorm(mu.a.jday, tau.a.jday)
    a.bft[t] ~ dnorm(mu.a.bft, tau.a.bft)
    a.eff[t] ~ dnorm(mu.a.eff, tau.a.eff)
    
    g.0[t] ~ dnorm(mu.g.0, tau.g.0)
    e.0[t] ~ dnorm(mu.e.0, tau.e.0)
    
    ### Process & Observation model of points
    for (j in 1:n.site) {
      
      # Occupancy for season 1 in each year, but no covariates here
      logit(psi[j, 1, t]) <- b.0[t]
      Z[j, 1, t] ~ dbin(psi[j, 1, t], 1)
      
      # Detectability for season 1 in each year
      for(k in 1:n.visit) {
        logit(p[j, k, 1, t]) <- a.0[t] + a.jday[t] * jday[j, k, 1, t] + a.bft[t] * bft[j, k, 1, t] + a.eff[t] * eff[j, k, 1, t]
        mu.p[j, k, 1, t] <- p[j, k, 1, t] * Z[j, 1, t]
        y[j, k, 1, t] ~ dbin(mu.p[j, k, 1, t], 1)
      }
      
      # Colonization & persistence for seasons 2-4 in each year, using Socolar offset method (deltas) to look at phenological shift
      for(l in 2:n.season) {
        
        logit(phi[j, l-1, t]) <- e.0[t]
        logit(gamma[j, l-1, t]) <- g.0[t]
        psi[j, l, t] <- phi[j, l-1, t]*Z[j, l-1, t] + gamma[j, l-1, t]*(1 - Z[j, l-1, t])
        Z[j, l, t] ~ dbin(psi[j, l, t], 1)
        
        # Detectability for seasons 2-4 in each year
        for(k in 1:n.visit) {
          logit(p[j, k, l, t]) <- a.0[t] + a.jday[t] * jday[j, k, l, t] + a.bft[t] * bft[j, k, l, t] + a.eff[t] * eff[j, k, l, t]
          mu.p[j, k, l, t] <- p[j, k, l, t] * Z[j, l, t]
          y[j, k, l, t] ~ dbin(mu.p[j, k, l, t], 1)
        }
      }
    }
  }
}

nc <- 3 #initset[1]
n.adapt <- 1000 #initset[2]
n.burn <- 1000 #initset[3]
n.iter <- 4000 #initset[4]
thin <- 10 #initset[5]

pars <- c("mu.b.0", "mu.a.0", "mu.a.jday", "mu.a.bft", "mu.a.eff", "mu.g.0", "mu.e.0")
#pars <- c("Z")

### Parallelize across chains ##
start.time<-Sys.time()
cl <- makePSOCKcluster(nc)   # Make your socket cluster and name it 'cl'.  nc is the number of cores you want your cluster to have--generally the number of chains you want to run, hence the name.
tmp <- clusterEvalQ(cl, library(dclone))  # Check that `dclone` is loaded on each of cl's workers.  dclone includes JAGS functionality
parLoadModule(cl, "glm")  # load the JAGS module 'glm' on each worker
parListModules(cl)  # make sure previous line worked.
whale.pars <- jags.parfit(cl, jags.data, params = pars, whale.mod, inits=inits, n.chains=nc,
                          n.adapt=n.adapt, n.update = n.burn, thin = thin, n.iter = n.iter)
stopCluster(cl)    # close out the cluster.
end.time=Sys.time()
elapsed.time = difftime(end.time, start.time, units='hours')
elapsed.time 

plot(whale.pars)
summary(whale.pars)