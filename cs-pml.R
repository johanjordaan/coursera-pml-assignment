library("RUnit")
library("data.table")
library("caret")
library("rattle")
library("glmnet")


# Load the data and do some preliminary cleaning
#
trainData <- fread("pml-training.csv")
trainData <- trainData[,-c(1:6),with=F]
trainData <- trainData[,lapply(.SD,function(x) {
  x[x==""] <- NA
  x[x=="NA"] <- NA

  if(sum(x == trainData$classe,na.rm=TRUE) == length(trainData$classe)) {
    return(as.factor(x))
  } else {
    x[is.na(x)] <- 0
    x <- as.numeric(x);
    x[is.na(x)] <- 0
  }
    
  return(x);  
})]

trainData <- as.data.frame(trainData)

trainDataClasses <- lapply(trainData,class)
stopifnot(sum(trainDataClasses == 'numeric') == 153)
stopifnot(sum(trainDataClasses == 'factor') == 1)


# Partition data into training and cv sets
# NOTES: Does this randomise the order?
#
#folds <- createFolds(trainData$classe,k=10,list=TRUE,returnTrain=TRUE)
#resa <- createResample(trainData$classe,times=10,list=TRUE)
set.seed(1337)
inTrain <- createDataPartition(trainData$classe,p=0.75,list=FALSE)
tr <- trainData[inTrain,]
cv <- trainData[-inTrain,]

# Lets try piecewise logistic regression
#
fitModels <- function(data,p) {
  p <- deparse(substitute(p))
  backup <- data[[p]]
  levels = levels(data[[p]])  
  retVal = vector(mode="list")

  for(i in levels) {
    print(i)
    data[[p]] <- as.factor(backup==i)
    model <- train(as.formula(paste(p,"~.")),data=data,method="glm")
    print(confusionMatrix(model))
    retVal[[i]] <- model
  }
  data[[p]] <- backup
  return(retVal);
}

models <- fitModels(tr,classe)

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



testData <- fread("pml-testing.csv")
testData <- testData[,-c(1:6),with=F]
testData <- testData[,lapply(.SD,function(x) {
  x[x==""] <- NA
  x[x=="NA"] <- NA
  
  x[is.na(x)] <- 0
  x <- as.numeric(x);
  x[is.na(x)] <- 0

  return(x);  
})]
testData$problem_id <- NULL
testData <- as.data.frame(testData)



testData <- useModels(models,classe,testData,levels(trainData$classe))









#trainData <- factorise(trainData)

#control <- trainControl(method="repeatedcv", number=10, repeats=3)
#model <- train(trainData,trainDataRes,method="rpart",preProcess="scale", trControl=control, tuneLength=5)

#trainData <- trainData[,apply(trainData, 2, var, na.rm=TRUE) != 0]

#preprocessParams <- preProcess(trainData, method=c("center", "scale", "pca"))

#print(preprocessParams)

#transformed <- predict(preprocessParams, trainData)
#transformed <- factorise(transformed)
#m <- train(transformed,trainDataRes,method="rf")
#fancyRpartPlot(m$finalModel)

#trainData <- factorise(trainData)
#testData <- factorise(testData)


#tree <- train(trainData,trainDataRes,method="rpart")
#tree2 <- train(v,res,method="gbm")

#fancyRpartPlot(tree$finalModel)
#fancyRpartPlot(tree2$finalModel)

#tree3 <- train(v,res,method="rf")

