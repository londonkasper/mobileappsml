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
        dsid = self.get_int_arg("dsid",default=0)

        data = await self.get_features_and_labels_as_SFrame(dsid)

        # fit the model to the data
        acc = -1
        best_model = 'unknown'
        if len(data)>0:
            
            model = tc.classifier.create(data,target='target',verbose=0)# training
            yhat = model.predict(data)
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

class PredictOneFromDatasetId(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector
        '''
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        dsid  = data['dsid']

        # load the model from the database (using pickle)
        # we are blocking tornado!! no!!
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

class UpdateGivenModel(BaseHandler):
    async def post(self):
        inputs = json.loads(self.request.body.decode("utf-8"))    
        data = await self.get_features_and_labels_as_SFrame(inputs['dsid'])
        
        model_type = inputs['type']

        if len(data)>0:
            if model_type == 'rfc':
                iters = inputs['max_iters']
                depth = inputs['max_depth']
                if depth == 0:  model = tc.random_forest_classifier.create(data,target='target',verbose=0,max_iterations=iters)
                else: model = tc.random_forest_classifier.create(data,target='target',verbose=0,max_iterations=iters,max_depth=depth)
            elif model_type == 'knn':
                distance = inputs['distance']
                model = tc.nearest_neighbors.create(data,target='target',verbose=0,distance=distance)

            yhat = model.predict(data)
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