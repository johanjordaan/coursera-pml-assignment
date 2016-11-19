cleanData <- function(x) {
  x[x==""] <- NA
  x[x=="NA"] <- NA
  
  x[is.na(x)] <- 0
  x <- as.numeric(x);
  x[is.na(x)] <- 0
  
  return(x);  
}

trainData <- fread("pml-training.csv")
trainDataUserNames <- trainData$user_name
trainDataClasse <- as.factor(trainData$classe) 
classeIndex <- which(names(trainData)=="classe")
trainData <- trainData[,-c(1:6,classeIndex),with=F]
trainData <- trainData[,lapply(.SD,cleanData)]

nearZeroVarCols <- nearZeroVar(trainData)
nearZeroVarColsRemoved <- names(trainData)[nearZeroVarCols]
trainData <- data.table(data.frame(trainData)[, -nearZeroVarCols])


testData <- fread("pml-testing.csv")
problemIdIndex <- which(names(testData)=="problem_id")
testData <- testData[,-c(1:6,problemIdIndex),with=F]
testData <- testData[,lapply(.SD,cleanData)]

testDataNearZeroVarCols = which(names(testData) %in% nearZeroVarColsRemoved)
testData <- data.table(data.frame(testData)[, -(testDataNearZeroVarCols)])


print(setdiff(names(trainData),names(testData)))
print(setdiff(names(testData),names(trainData)))


