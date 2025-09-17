#!/usr/bin/groovy
@Grab('org.yaml:snakeyaml:1.29')
import org.yaml.snakeyaml.Yaml

// Read pipeline manifest
def manifestContent = readFileFromWorkspace('job-dsl/manifests/pipeline.yaml')
def manifest = new Yaml().load(manifestContent)

// Create jobs at root level
manifest.jobs.each { job ->
  def jobPath = job.name
  
  if(job.type == "SINGLE") {
    pipelineJob(jobPath) {
      displayName(job.name)
      definition {
        cpsScm {
          scriptPath(job.script_path ?: 'Jenkinsfile')
          scm {
            git {
              remote {
                url("http://k8s-gitlab-gitlabwe-11c16d8044-709872649.ap-southeast-1.elb.amazonaws.com/${job.git_path}")
                credentials('gitlab-cred')
              }
              branch(job.branch ?: 'main')
            }
          }
        }
      }
    }
  }
}

