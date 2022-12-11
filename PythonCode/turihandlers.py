#!/usr/bin/python

from pymongo import MongoClient
import tornado.web

from tornado.web import HTTPError
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop
from tornado.options import define, options

from basehandler import BaseHandler

import turicreate as tc
import pickle
from bson.binary import Binary
import json
import numpy as np

class PrintHandlers(BaseHandler):
    def get(self):
        '''Write out to screen the handlers used
        This is a nice debugging example!
        '''
        self.set_header("Content-Type", "application/json")
        self.write(self.application.handlers_string.replace('),','),\n'))

class UploadLabeledDatapointHandler(BaseHandler):
    async def post(self):
        '''Save data point and class label to database
        '''
        data = json.loads(self.request.body.decode("utf-8"))

        vals = data['feature']
        fvals = [float(val) for val in vals]
        label = data['label']
        # all data still saved with dsid of 0
        sess  = data['dsid']

        dbid = await self.db.labeledinstances.insert_one(
            {"feature":fvals,"label":label,"dsid":sess}
            );
        self.write_json({"id":str(dbid),
            "feature":[str(len(fvals))+" Points Received",
                    "min of: " +str(min(fvals)),
                    "max of: " +str(max(fvals))],
            "label":label})

class RequestNewDatasetId(BaseHandler):
    async def get(self):
        '''Get a new dataset ID for building a new dataset
        '''
        a = await self.db.labeledinstances.find_one(sort=[("dsid", -1)])
        if a == None:
            newSessionId = 1
        else:
            newSessionId = float(a['dsid'])+1
        self.write_json({"dsid":newSessionId})

class UpdateModelForDatasetId(BaseHandler):
    async def get(self):
        '''Train a new model (or update) for given dataset ID
        '''
        print("TEST")
        dsid = self.get_int_arg("dsid",default=0)

        data = await self.get_features_and_labels_as_SFrame(dsid)

        # fit the model to the data
        acc = -1
        best_model = 'unknown'
        if len(data)>0:
            
            model = tc.classifier.create(data,target='target',verbose=0)# training
            yhat = model.predict(data)
            # saves model under 'best', allowing it to be used throughout module A
            self.clf['best'] = model
            acc = sum(yhat==data['target'])/float(len(data))
            # save model for use later, if desired
            model.save('../models/turi_model_dsid%d'%(dsid))
            

        # send back the resubstitution accuracy
        # if training takes a while, we are blocking tornado!! No!!
        self.write_json({"resubAccuracy":acc})

    async def get_features_and_labels_as_SFrame(self, dsid):
        # create feature vectors from database
        features=[]
        labels=[]
        async for a in self.db.labeledinstances.find({'dsid': dsid}):
            features.append([float(val) for val in a['feature']])
            labels.append(a['label'])

        # convert to dictionary for tc
        data = {'target':labels, 'sequence':np.array(features)}

        # send back the SFrame of the data
        return tc.SFrame(data=data)

class Predict(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector
        '''
        print("HERE")
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        dsid  = data['dsid']

        # checks to see if 'best' model has been trained
        # if model has not been trained, a JSON with unique key "trained" will be returned
        if 'best' not in self.clf:
            self.write_json({"trained":False})
  
        else:
            predLabel = self.clf['best'].predict(fvals);
            self.write_json({"prediction":str(predLabel)})

    def get_features_as_SFrame(self, vals):
        # create feature vectors from array input
        # convert to dictionary of arrays for tc

        tmp = [float(val) for val in vals]
        tmp = np.array(tmp)
        tmp = tmp.reshape((1,-1))
        data = {'sequence':tmp}

        # send back the SFrame of the data
        return tc.SFrame(data=data)

class UpdateWithGivenModel(BaseHandler):
    async def post(self):
        '''Train a new model (or update) for given model type
           Either Random Forest or Boosted Tree
        '''
        print(self.request.body)
        inputs = json.loads(self.request.body.decode("utf-8"))   
        data = await self.get_features_and_labels_as_SFrame(inputs['dsid'])
        # get the model type, either 'rfc' or 'btm'
        model_type = inputs['type']

        if len(data)>0:
            iters = inputs['max_iters']
            depth = inputs['max_depth']
            # creates random forest model
            if model_type == 'rfc':
                # if depth is equal to 0, default max_depth is used
                if depth == "0": model = tc.random_forest_classifier.create(data,target='target',verbose=0,max_iterations=iters)
                else: model = tc.random_forest_classifier.create(data,target='target',verbose=0,max_iterations=iters,max_depth=depth)
            
            # creates boosted tree model
            elif model_type == 'btm':
                # if depth is equal to 0, default max_depth is used
                if depth == "0": model = tc.boosted_trees_classifier.create(data,target='target',verbose=0,max_iterations=iters)
                else: model = tc.boosted_trees_classifier.create(data,target='target',verbose=0,max_iterations=iters,max_depth=depth)

            yhat = model.predict(data)
            # model is saved in clf under either the 'rfc' or 'btm' label
            self.clf[model_type] = model
            acc = sum(yhat==data['target'])/float(len(data))
            

        # send back the resubstitution accuracy
        # if training takes a while, we are blocking tornado!! No!!
        self.write_json({"resubAccuracy":acc})
    
    async def get_features_and_labels_as_SFrame(self, dsid):
        # create feature vectors from database
        features=[]
        labels=[]
        async for a in self.db.labeledinstances.find({'dsid': dsid}):
            features.append([float(val) for val in a['feature']])
            labels.append(a['label'])

        # convert to dictionary for tc
        data = {'target':labels, 'sequence':np.array(features)}

        # send back the SFrame of the data
        return tc.SFrame(data=data)

class PredictWithGivenModel(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector using a specific model
        '''
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        model_type  = data['type']

        # checks to see if model from given type has been trained
        # if model has not been trained, a JSON with unique key "trained" will be returned
        if model_type not in self.clf:
            self.write_json({"trained":False})
  
        else:
            predLabel = self.clf[model_type].predict(fvals);
            self.write_json({"prediction":str(predLabel)})

    def get_features_as_SFrame(self, vals):
        # create feature vectors from array input
        # convert to dictionary of arrays for tc

        tmp = [float(val) for val in vals]
        tmp = np.array(tmp)
        tmp = tmp.reshape((1,-1))
        data = {'sequence':tmp}

        # send back the SFrame of the data
        return tc.SFrame(data=data)