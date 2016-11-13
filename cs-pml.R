library("RUnit")
library("data.table")
library("caret")
library("rattle")
library("glmnet")
library("GGally")

trainData <- fread("pml-training.csv")

# Sanity Check
sanityCheck <- function(data,numericCount,factorCount) {
  trainDataClasses <- lapply(data,class)
  stopifnot(sum(trainDataClasses == 'numeric') == numericCount)
  stopifnot(sum(trainDataClasses == 'factor') == factorCount)
}

# Save the user names and classes for later analysis
userNames <- trainData$user_name
classe <- as.factor(trainData$classe) 

# Remove the columns we are not interested in
classeIndex <- which(names(trainData)=="classe")
trainData <- trainData[,-c(1:6,classeIndex),with=F]

# Do simple cleaning
cleanData <- function(x) {
  x[x==""] <- NA
  x[x=="NA"] <- NA
  
  x[is.na(x)] <- 0
  x <- as.numeric(x);
  x[is.na(x)] <- 0
  
  return(x);  
}
trainData <- trainData[,lapply(.SD,cleanData)]

sanityCheck(trainData,153,0)


## Remove zerovariance
nearZeroVarCols <- nearZeroVar(trainData)
trainData <- data.table(data.frame(trainData)[, -nearZeroVarCols])

sanityCheck(trainData,53,0)

## PCA 
preprocessParams <- preProcess(trainData, method=c("center", "scale", "pca"))
trainDataPCA <- predict(preprocessParams, trainData)

sanityCheck(trainDataPCA,26,0)

## Explore the base data
ggplot(data=data.frame(classe),aes(x=classe))+geom_bar()
ggplot(data=data.frame(userNames),aes(x=userNames))+geom_bar()

## Explore the PCA data a bit
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=classe))+geom_point(alpha=0.2)
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=userNames))+geom_point(alpha=0.2)

# Conclusing at this point - The data needs to be scaled per user before pca
centerByUser <- function(data,userNames) {
  for(n in unique(userNames)) {
    m <- mean(data[userNames==n])
    data[userNames==n] <- data[userNames==n] - m
  }
  return(data)
}  
trainData <- trainData[,lapply(.SD,function(x){ centerByUser(x,userNames); })]

# Another round of PCA
preprocessParams <- preProcess(trainData, method=c("center", "scale", "pca"))
trainDataPCA <- predict(preprocessParams, trainData)

sanityCheck(trainDataPCA,33,0)

## Explore the PCA data a bit
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=classe))+geom_point(alpha=0.2)
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=userNames))+geom_point(alpha=0.2)

## Find the one weird outlier and deal with it ... This migth be an issue in testing ?
classe <- classe[trainDataPCA$PC2>-40]
userNames <- userNames[trainDataPCA$PC2>-40]
trainDataPCA <- trainDataPCA[trainDataPCA$PC2>-40,]

## Explore the PCA data a bit
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=classe))+geom_point(alpha=0.2)
ggplot(trainDataPCA,aes(x=PC1,y=PC2,color=userNames))+geom_point(alpha=0.2)


# Partition data into training and cv sets

# Lets try piecewise logistic regression
#
fitModels <- function(x,y) {
  levels = levels(y)  
  retVal = vector(mode="list")

  for(i in levels) {
    print(i)
    y_i <- as.factor(y==i)
    model <- train(x=x,y=y_i,method="glm",family="binomial")
    print(confusionMatrix(model))
    retVal[[i]] <- model
  }
  return(retVal)
}


set.seed(1337)
inTrain <- createDataPartition(classe,p=0.75,list=FALSE)

tr <- trainDataPCA[inTrain,]
tr_cl <- classe[inTrain]
cv <- trainDataPCA[-inTrain,]
cv_cl <- classe[-inTrain]
models <- fitModels(tr,tr_cl)

tr2 <- trainData[inTrain,]
tr2_cl <- classe[inTrain]
cv2 <- trainData[-inTrain,]
cv2_cl <- classe[-inTrain]
models2 <- fitModels(tr2,tr2_cl)


useModels = function(m,p,t,levels) {
  p <- deparse(substitute(p))
  backup <- t[[p]]

  tmp = vector(mode='list')
  
  for(i in levels) {
    tmp[[i]] <- predict(m[[i]],newdata = t, type="prob")$`TRUE`
  }

  tmp <- as.data.frame(tmp)
  
  # TODO: Hack, this can be done more functionally
  t$pred <- rep(NA,nrow(t))
  for(i in 1:nrow(tmp)) {
    bestFit <- -1
    for(n in levels) {
      if(tmp[[n]][i]>bestFit) {
        bestFit <- tmp[[n]][i]
        t$pred[i] <- n
      }       
    }
  }

  t[[p]] <- backup
  return(t)
}

cv$classe <- cv_cl 
cvRes <- useModels(models,classe,cv,levels(cv_cl))$pred

cv2$classe <- cv2_cl 
cv2Res <- useModels(models2,classe,cv2,levels(cv2_cl))$pred



testData <- fread("pml-testing.csv")
testDataUserNames = testData$user_names 
testDataClasse = testData$classe
testData <- testData[,-c(1:6,which(names(testData)=="problem_id")),with=F]
testData <- testData[,lapply(.SD,cleanData)]

# Apply the same transformation on test data
testData <- data.table(data.frame(testData)[, -nearZeroVarCols])
testData <- testData[,lapply(.SD,function(x){ centerByUser(x,testDataUserNames); })]
testDataPCA <- predict(preprocessParams, testData)

testDataRes <- useModels(models,classe,testDataPCA,levels(classe))$pred







#BABAAEDeAAdaBAEEABaB


